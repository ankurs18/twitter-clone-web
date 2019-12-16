defmodule TwitterWeb.TweetChannel do
  use TwitterWeb, :channel
  require Logger

  def join("tweet:" <> tokenid, payload, socket) do
    if authorized?(payload) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # # Channels can be used in a request/response fashion
  # # by sending replies to requests from the client
  # def handle_in("login_user", payload, socket) do
  #   {:reply, {:ok, payload}, socket}
  # end

  def handle_in("register_user", payload, socket) do
    %{"username" => username} = payload
    # IO.inspect({"SOCKET", socket})
    {status} = Twitter.Server.register_user(username, socket.assigns.session_id)

    error_response = %{
      error: true,
      response: "Username already in use!"
    }

    success_response = %{
      error: false,
      response: "Success"
    }

    case status do
      :duplicate_user_error ->
        TwitterWeb.Endpoint.broadcast(socket.topic, "user_registered", error_response)

        # push(socket, "user_registered", %{error: true, response: "Username already in use!"})
        {:reply, {:error, error_response}, socket}

      _ ->
        TwitterWeb.Endpoint.broadcast(socket.topic, "user_registered", success_response)

        # push(socket, "user_registered", %{error: false, response: "Success"})
        {:reply, {:ok, success_response}, socket}
    end
  end

  def handle_in("login_user", payload, socket) do
    %{"username" => username} = payload
    {status, feeds} = Twitter.Server.login_user(username, socket.assigns.session_id)

    error_response = %{
      error: true,
      response: "Username doesn't exist!"
    }

    success_response = %{error: false, response: feeds}

    case status do
      :failure ->
        TwitterWeb.Endpoint.broadcast(socket.topic, "user_loggedin", error_response)
        # push(socket, "user_registered", %{error: true, response: "Username already in use!"})
        {:reply, {:error, error_response}, socket}

      _ ->
        socket = assign(socket, :username, username)
        TwitterWeb.Endpoint.broadcast(socket.topic, "user_loggedin", success_response)
        # push(socket, "user_registered", %{error: false, response: "Success"})
        {:reply, {:ok, success_response}, socket}
    end
  end

  def handle_in("tweet", payload, socket) do
    %{"tweet" => tweet, "user" => user} = payload
    Twitter.Server.tweet(tweet, user)
    {:reply, :ok, socket}
  end

  def handle_in("retweet", payload, socket) do
    %{"tweet_id" => tweet_id, "user" => user} = payload
    Twitter.Server.retweet(tweet_id, user)
    {:noreply, socket}
  end

  def handle_in("follow", payload, socket) do
    %{"follower" => follower, "following" => following} = payload
    {status, _} = Twitter.Server.follow_user(follower, following)

    case status do
      :failure ->
        # push(socket, "follow_response", %{
        #   error: true,
        #   response: "Username doesn't exist!"
        # })

        {:reply,
         {:error,
          %{
            error: true,
            response: "Username doesn't exist!"
          }}, socket}

      _ ->
        # push(socket, "follow_response", %{
        #   error: false,
        #   response: "success"
        # })

        {:reply,
         {:ok,
          %{
            error: false,
            response: "success"
          }}, socket}
    end
  end

  def handle_in("query_hashtag", payload, socket) do
    result = Map.get(payload, "hashtag") |> Twitter.Server.query_hashtag()

    if(length(result) > 0) do
      {:reply, {:ok, %{error: false, response: result}}, socket}
    else
      {:reply, {:error, %{error: true, response: "No tweet found"}}, socket}
    end
  end

  def handle_in("query_mentions", payload, socket) do
    result = Map.get(payload, "user") |> Twitter.Server.query_mentions()

    if(length(result) > 0) do
      {:reply, {:ok, %{error: false, response: result}}, socket}
    else
      {:reply, {:error, %{error: true, response: "No tweet found"}}, socket}
    end
  end

  def handle_in("query_subscribed_tweets", payload, socket) do
    result = Map.get(payload, "user") |> Twitter.Server.query_subscribed_tweets()

    if(length(result) > 0) do
      {:reply, {:ok, %{error: false, response: result}}, socket}
    else
      {:reply, {:error, %{error: true, response: "No tweet found"}}, socket}
    end
  end

  def handle_in("query_my_own_tweets", payload, socket) do
    result = Map.get(payload, "user") |> Twitter.Server.query_own_tweets()

    if(length(result) > 0) do
      {:reply, {:ok, %{error: false, response: result}}, socket}
    else
      {:reply, {:error, %{error: true, response: "No tweet found"}}, socket}
    end
  end

  def handle_in("delete_account", payload, socket) do
    result = Map.get(payload, "user") |> Twitter.Server.delete_account()

    {:reply, {:ok, %{response: "Deleted!"}}, socket}
  end

  def handle_in("logout", payload, socket) do
    result = Map.get(payload, "user") |> Twitter.Server.logout_user()

    {:reply, {:ok, %{response: "Logged out!"}}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (tweet:lobby).
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
