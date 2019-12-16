let show_query = () => {
  $(".col.feed").hide();
  $(".col.query").show();
};

export function register(channel, callback) {
  let username = document.querySelector("#orangeForm-username").value;

  if (username) {
    channel
      .push("register_user", { username: username })
      .receive("ok", payload => {
        window.USER_ACTIVE = true;
        $("#orangeForm-username").val("");
        $("#orangeForm-error").html("");
        document.querySelector("#modalRegisterForm .close").click();
        callback(username);
      })
      .receive("error", payload => {
        // window.location = "./feed";
        $("#orangeForm-username").val("");
        $("#orangeForm-error").html(payload.response);
      });
  } else {
    alert("Username missing");
  }
}

export function login(channel, callback) {
  let username = document.querySelector("#loginForm-username").value;
  //   let password = document.querySelector("#orangeForm-pass").value;
  //   console.log(username);
  if (username) {
    channel
      .push("login_user", { username: username })
      .receive("ok", payload => {
        window.USER_ACTIVE = true;
        $("#loginForm-username").val("");
        $("#loginForm-error").html("");
        document.querySelector("#modalLoginForm .close").click();
        callback(username);
        renderTweet(payload.response);
      })
      .receive("error", payload => {
        $("#loginForm-username").val("");
        $("#loginForm-error").html(payload.response);
      });
  } else {
    alert("Username missing");
  }
}

// channel.on("user_loggedin", payload => {

// });

export function tweet(channel, user) {
  let tweet = $("#tweet-textbox input").val();
  //   let password = document.querySelector("#orangeForm-pass").value;
  //   console.log(username);

  if (tweet) {
    channel.push("tweet", { user: user, tweet: tweet }).receive("ok", () => {
      $("#tweet-textbox input").val("");
    });
  }
}

export function follow(channel, follow_username) {
  let user = follow_username.split("@")[1];
  if (user) {
    channel
      .push("follow", {
        follower: window.username,
        following: user
      })
      .receive("ok", () => {
        $("#follow-user").val("");
      })
      .receive("error", payload => {
        alert(payload.response);
      });
  }
}
export function queryHashTags(channel, hashtag) {
  let tag = hashtag.split("#")[1];
  if (tag) {
    show_query();
    channel
      .push("query_hashtag", { hashtag: tag })
      .receive("ok", payload => {
        $("#hashtag-input").val("");
        $("#no-result").empty();
        $("#res-list").empty();
        renderTweet(payload.response, $("#res-list"));
      })
      .receive("error", () => {
        $("#res-list").empty();
        $("#hashtag-input").val("");
        $("#no-result").text("No tweet found");
      });
  }
}

export function queryMentions(channel, user) {
  if (user) {
    show_query();
    channel
      .push("query_mentions", { user: user })
      .receive("ok", payload => {
        $("#no-result").empty();
        $("#res-list").empty();
        renderTweet(payload.response, $("#res-list"));
      })
      .receive("error", () => {
        $("#res-list").empty();
        $("#no-result").text("No tweet found");
      });
  }
}

export function querySubscribed(channel, user) {
  if (user) {
    show_query();
    channel
      .push("query_subscribed_tweets", { user: user })
      .receive("ok", payload => {
        $("#no-result").empty();
        $("#res-list").empty();
        renderTweet(payload.response, $("#res-list"));
      })
      .receive("error", () => {
        $("#res-list").empty();
        $("#no-result").text("No tweet found");
      });
  }
}

export function queryOwnTweets(channel, user) {
  if (user) {
    show_query();
    channel
      .push("query_my_own_tweets", { user: user })
      .receive("ok", payload => {
        $("#no-result").empty();
        $("#res-list").empty();
        renderTweet(payload.response, $("#res-list"));
        $(".retweet").hide();
      })
      .receive("error", () => {
        $("#res-list").empty();
        $("#no-result").text("No tweet found");
      });
  }
}

export function deleteAccount(channel, user) {
  if (user) {
    channel.push("delete_account", { user: user }).receive("ok", () => {
      window.location.reload(true);
    });
  }
}

export function logout(channel, user) {
  if (user) {
    channel.push("logout", { user: user }).receive("ok", () => {
      window.location.reload(true);
    });
  }
}

export function retweet(channel, user, tweet_id) {
  //   let password = document.querySelector("#orangeForm-pass").value;
  //   console.log(username);
  channel.push("retweet", { user, tweet_id }).receive("ok", () => {});
}

export function renderTweet(tweets, ref, hideRetweet) {
  let tweetArray = [];
  if (!Array.isArray(tweets)) {
    tweetArray.push(tweets);
  } else {
    tweetArray = tweets;
  }
  let feedRef = ref ? ref : $("#msg-list");
  // original_tweeter
  tweetArray.map(tweet => {
    let li;
    if (tweet.original_tweeter) {
      li = $(
        `<li id="${tweet.tweet_id}" class="tweet retweet">
            <div class="tweeter">${tweet.tweeter}</div>
            <div class="tweet">
                <div class="tweeter">${tweet.original_tweeter}</div>
                <div class="tweet-text">${tweet.tweet}</div>
             </div> 
            <a class="btn btn-secondary retweet">Retweet</a>
        </li>`
      );
    } else {
      li = $(
        `<li id="${tweet.tweet_id}" class="tweet">
            <div class="tweeter">${tweet.tweeter}</div>
            <div class="tweet-text">${tweet.tweet}</div>
            <a class="btn btn-secondary retweet">Retweet</a>
        </li>`
      );
    }

    feedRef.prepend(li);
    $(li)
      .find(".retweet")
      .on("click", event => {
        let id = $(event.target)
          .parent(".tweet")
          .attr("id");
        retweet(window.local_channel, window.username, id);
      });
  });
}
