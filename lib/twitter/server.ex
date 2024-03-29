defmodule Twitter.Server do
  use GenServer
  require Logger

  ############################## API #################################

  def start_link(_) do
    GenServer.start_link(__MODULE__, :no_args, name: :server)
  end

  def init(_) do
    :ets.new(:users, [:ordered_set, :public, :named_table])

    :ets.new(:active_users, [
      :ordered_set,
      :public,
      :named_table,
      write_concurrency: true,
      read_concurrency: true
    ])

    :ets.new(:tweets, [:ordered_set, :public, :named_table])
    :ets.new(:hashtags, [:ordered_set, :public, :named_table])
    {:ok, {}}
  end

  def register_user(user_name, user_pid),
    do: GenServer.call(:server, {:register_user, user_name, user_pid}, :infinity)

  def login_user(user_name, user_pid),
    do: GenServer.call(:server, {:login_user, user_name, user_pid}, :infinity)

  def logout_user(user_name),
    do: GenServer.cast(:server, {:logout_user, user_name})

  def follow_user(follower_id, following_id),
    do: GenServer.call(:server, {:follow_user, follower_id, following_id}, :infinity)

  def query_own_tweets(username),
    do: GenServer.call(:server, {:get_user_tweets, username}, :infinity)

  def query_hashtag(hashtag),
    do: GenServer.call(:server, {:query_hashtag, hashtag}, :infinity)

  def query_mentions(username),
    do: GenServer.call(:server, {:query_mentions, username}, :infinity)

  def query_subscribed_tweets(username),
    do: GenServer.call(:server, {:query_subscribed_tweets, username}, :infinity)

  def tweet(tweet, username),
    do: GenServer.cast(:server, {:handle_tweet, tweet, username})

  def retweet(tweet_id, username),
    do: GenServer.cast(:server, {:retweet, tweet_id, username})

  def delete_account(username),
    do: GenServer.cast(:server, {:delete_account, username})

  ############################## Server #################################

  def handle_call({:query_subscribed_tweets, username}, _from, _state) do
    {:reply, fetch_subscibed_tweets(username), {}}
  end

  def handle_call({:query_mentions, username}, _from, _state) do
    {:reply, fetch_mentions(username), {}}
  end

  def handle_call({:get_user_tweets, username}, _from, _state) do
    [user] = :ets.lookup(:users, username)
    usermap = elem(user, 1)
    tweet_ids = Map.get(usermap, :tweet_ids, [])

    tweets_list =
      Enum.reduce(tweet_ids, [], fn tweet_id, acc ->
        [parse_tweet_tuple(get_tweet(tweet_id)) | acc]
      end)

    {:reply, tweets_list, {}}
  end

  def handle_call({:query_hashtag, hashtag}, _from, _state) do
    tweet_ids = :ets.lookup(:hashtags, hashtag)

    tweets_list =
      if tweet_ids == [] do
        []
      else
        tweet_ids = Enum.at(tweet_ids, 0) |> elem(1)

        Enum.reduce(tweet_ids, [], fn tweet_id, acc ->
          [tup] = :ets.lookup(:tweets, tweet_id)
          [parse_tweet_tuple(tup) | acc]
        end)
      end

    {:reply, tweets_list, {}}
  end

  def handle_call({:follow_user, follower_id, following_id}, _from, _state) do
    follower = :ets.lookup(:users, follower_id)
    following = :ets.lookup(:users, following_id)

    if length(follower) > 0 and length(following) > 0 do
      [{follower_id, follower_map}] = follower
      [{following_id, following_map}] = following
      following_list = [following_id | Map.get(follower_map, :following, [])]
      follower_map = Map.put(follower_map, :following, Enum.uniq(following_list))
      follower_list = [follower_id | Map.get(following_map, :followers, [])]
      following_map = Map.put(following_map, :followers, Enum.uniq(follower_list))

      :ets.insert(:users, {follower_id, follower_map})
      :ets.insert(:users, {following_id, following_map})
      {:reply, {:success, nil}, {}}
    else
      {:reply, {:failure, :user_not_found}, {}}
    end
  end

  def handle_call({:register_user, user_name, pid}, _from, _state) do
    is_inserted = :ets.insert_new(:users, {user_name, %{}})

    if is_inserted == true do
      :ets.insert_new(:active_users, {user_name, pid})
      {:reply, {:success}, {}}
    else
      {:reply, {:duplicate_user_error}, {}}
    end
  end

  def handle_call({:login_user, username, session_id}, _from, _state) do
    user = :ets.lookup(:users, username)

    if length(user) > 0 do
      :ets.insert(:active_users, {username, session_id})
      {:reply, {:success, fetch_feed(username)}, {}}
    else
      {:reply, {:failure, session_id}, {}}
    end
  end

  def handle_cast({:handle_tweet, tweet, username}, _state) do
    tweet_id = UUID.uuid1()
    tweet_tuple = {tweet_id, tweet, username, nil}
    :ets.insert(:tweets, tweet_tuple)
    [user] = :ets.lookup(:users, username)
    usermap = elem(user, 1)
    usermap = Map.put(usermap, :tweet_ids, [tweet_id | Map.get(usermap, :tweet_ids, [])])
    :ets.insert(:users, {username, usermap})

    users_mentioned_list =
      if String.contains?(tweet, "@") do
        users_mentioned = parse_mentions(tweet)
        # IO.inspect({"mention", users_mentioned})

        if length(users_mentioned) > 0 do
          Enum.each(users_mentioned, &process_mentions(&1, tweet_tuple))
        end

        users_mentioned
      else
        []
      end

    distribute_to_following(tweet_tuple, users_mentioned_list)

    if String.contains?(tweet, "#") do
      hashtags = parse_hashtags(tweet)
      # IO.inspect({"hastags", hashtags})

      if length(hashtags) > 0 do
        Enum.each(hashtags, &process_hashtags(&1, tweet_id))
      end
    end

    {:noreply, {}}
  end

  def handle_cast({:retweet, original_tweet_id, username}, _state) do
    {_, tweet, original_tweeter, _} = get_tweet(original_tweet_id)
    new_tweet_id = UUID.uuid1()
    new_tweet = {new_tweet_id, tweet, username, original_tweeter}
    :ets.insert(:tweets, new_tweet)
    [user] = :ets.lookup(:users, username)
    usermap = elem(user, 1)
    usermap = Map.put(usermap, :tweet_ids, [new_tweet_id | Map.get(usermap, :tweet_ids, [])])
    :ets.insert(:users, {username, usermap})
    distribute_to_following(new_tweet, [])
    {:noreply, {}}
  end

  def handle_cast({:logout_user, username}, _state) do
    Logger.debug("logging out #{username}")
    :ets.delete(:active_users, username)
    {:noreply, {}}
  end

  def handle_cast({:delete_account, username}, _state) do
    [user] = :ets.lookup(:users, username)
    usermap = elem(user, 1)

    :ets.delete(:users, username)
    :ets.delete(:active_users, username)
    {:noreply, {}}
  end

  def fetch_feed(username) do
    x = fetch_subscibed_tweets(username)
    y = fetch_mentions(username)
    Enum.uniq(x ++ y)
  end

  def fetch_subscibed_tweets(username) do
    [user] = :ets.lookup(:users, username)
    usermap = elem(user, 1)
    following = Map.get(usermap, :following, [])

    Enum.reduce(following, [], fn following_username, acc ->
      get_user_tweets(following_username) ++ acc
    end)
  end

  def fetch_mentions(username) do
    [user] = :ets.lookup(:users, username)
    usermap = elem(user, 1)
    mentions = Map.get(usermap, :mentions, [])

    tweets_list =
      Enum.reduce(mentions, [], fn tweet_id, acc ->
        [parse_tweet_tuple(get_tweet(tweet_id)) | acc]
      end)

    tweets_list
  end

  def parse_mentions(tweet) do
    charlist = to_charlist(tweet)
    tweet_length = length(charlist)

    Enum.reduce(Enum.with_index(charlist), [], fn {c, i}, acc ->
      if c == 64 do
        if i == 0 or Enum.at(charlist, i - 1) == 32 do
          sublist_to_right = Enum.slice(charlist, i + 1, tweet_length - i + 1)
          len = length(sublist_to_right)
          # IO.inspect({"sublist", c, i, sublist_to_right})
          index_of_space = Enum.find_index(sublist_to_right, fn x -> x == 32 end)

          mentioned_user_name =
            if index_of_space != nil,
              do: Enum.slice(sublist_to_right, 0, index_of_space),
              else: Enum.slice(sublist_to_right, 0, len)

          [List.to_string(mentioned_user_name) | acc]
        else
          acc
        end
      else
        acc
      end
    end)
  end

  def parse_hashtags(tweet) do
    charlist = to_charlist(tweet)
    tweet_length = length(charlist)

    Enum.reduce(Enum.with_index(charlist), [], fn {c, i}, acc ->
      if c == 35 do
        if i == 0 or Enum.at(charlist, i - 1) == 32 do
          sublist_to_right = Enum.slice(charlist, i + 1, tweet_length - i + 1)
          len = length(sublist_to_right)
          # IO.inspect({"sublist", c, i, sublist_to_right})
          index_of_space = Enum.find_index(sublist_to_right, fn x -> x == 32 end)

          mentioned_user_name =
            if index_of_space != nil,
              do: Enum.slice(sublist_to_right, 0, index_of_space),
              else: Enum.slice(sublist_to_right, 0, len)

          [List.to_string(mentioned_user_name) | acc]
        else
          acc
        end
      else
        acc
      end
    end)
  end

  def get_user_tweets(username) do
    user = :ets.lookup(:users, username)

    if(length(user) > 0) do
      usermap = elem(Enum.at(user, 0), 1)
      tweet_ids = Map.get(usermap, :tweet_ids, [])

      Enum.reduce(tweet_ids, [], fn tweet_id, acc ->
        [parse_tweet_tuple(get_tweet(tweet_id)) | acc]
      end)
    else
      []
    end
  end

  def process_mentions(username, tweet_tuple) do
    user = :ets.lookup(:users, username)
    tweet_id = elem(tweet_tuple, 0)

    if length(user) > 0 do
      [{username, user_map}] = user
      mentioned_list = [tweet_id | Map.get(user_map, :mentions, [])]
      user_map = Map.put(user_map, :mentions, mentioned_list)
      :ets.insert(:users, {username, user_map})
      distribute_live(username, tweet_tuple)
    end
  end

  def distribute_to_following(tweet_tuple, users_mentioned_list) do
    tweeter = elem(tweet_tuple, 2)
    [{_, tweeter_map}] = :ets.lookup(:users, tweeter)
    followers = Map.get(tweeter_map, :followers, [])

    Enum.each(followers -- users_mentioned_list, fn follower_id ->
      distribute_live(follower_id, tweet_tuple)
    end)
  end

  def distribute_live(username, tweet_tuple) do
    user = :ets.lookup(:active_users, username)

    if length(user) > 0 do
      [{_, user_session_id}] = user
      # Twitter.Client.distribute_live(user_pid, tweet_tuple)
      success_response = parse_tweet_tuple(tweet_tuple)
      TwitterWeb.Endpoint.broadcast("tweet:#{user_session_id}", "shout_tweet", success_response)
    end
  end

  def process_hashtags(hashtag, tweet_id) do
    hashtag_list = :ets.lookup(:hashtags, hashtag)

    if length(hashtag_list) > 0 do
      # IO.inspect({hashtag, tweet_id, hashtag_list})
      [{_, hashtag_list}] = hashtag_list
      :ets.insert(:hashtags, {hashtag, [tweet_id | hashtag_list]})
    else
      # IO.inspect({hashtag, tweet_id, hashtag_list})
      :ets.insert(:hashtags, {hashtag, [tweet_id]})
    end
  end

  def whereis(user_name) do
    [tup] = :ets.lookup(:active_users, user_name)

    if length(tup) == 0 do
      nil
    else
      elem(tup, 1)
    end
  end

  def get_tweet(tweet_id) do
    lookup = :ets.lookup(:tweets, tweet_id)
    if length(lookup) > 0, do: Enum.at(lookup, 0), else: nil
  end

  def parse_tweet_tuple(tweet) do
    {tweet_id, tweet, tweeter, original_tweeter} = tweet

    %{
      "tweet_id" => tweet_id,
      "tweet" => tweet,
      "tweeter" => tweeter,
      "original_tweeter" => original_tweeter
    }
  end
end

# DateTime.now("Etc/UTC")
