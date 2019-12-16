// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import css from "../css/app.css";

// webpack automatically bundles all modules in your
// entry points. Those entry points can be configured
// in "webpack.config.js".
//
// Import dependencies
//

import "phoenix_html";

// Import local files
//
// Local files can be imported directly using relative paths, for example:
import socket from "./socket";
import {
  register,
  login,
  tweet,
  renderTweet,
  follow,
  queryHashTags,
  queryMentions,
  querySubscribed,
  queryOwnTweets,
  deleteAccount
} from "./main";

const rand = () =>
  Math.random(0)
    .toString(36)
    .substr(2);
const token = length => (rand() + rand()).substr(0, length);

window.USER_ACTIVE = false;
let USERNAME = null;

let hide_query = () => {
  $(".col.feed").show();
  $(".col.query").hide();
  $(".retweet").show();
};
let activate_user = function(username) {
  if (window.USER_ACTIVE) {
    document.querySelector("#login-logup").style.display = "none";
    document.querySelector("#user-login").style.display = "flex";
    document.querySelector("#main-wrapper").style.display = "flex";
    document.querySelector("#user-login .username").innerHTML = username;
    USERNAME = username;
    window.username = username;
  } else {
    document.querySelector("#user-login").style.display = "none";
    document.querySelector("#login-logup").style.display = "flex";
    document.querySelector("#main-wrapper").style.display = "none";
    document.querySelector("#user-login .username").innerHTML = "";
    USERNAME = null;
  }
};
activate_user();
let channel = socket(token(40));

window.local_channel = channel;
let login_button = document.querySelector("#login-btn ");
login_button.addEventListener("click", event => {
  let username = document.querySelector("#loginForm-username");
  //   let password = document.querySelector("#loginForm-pass");
});

channel.on("shout_tweet", payload => {
  renderTweet(payload);
});

$(".col.query").hide();

/* Register section*/
$("#orangeForm-username").on("keypress", event => {
  if (event.keyCode === 13) {
    register(channel, activate_user);
  }
});
$("#register-btn").on("click", event => {
  register(channel, activate_user);
});

$("#logout").on("click", event => {
  logout(channel, activate_user);
});

$("#loginForm-username").on("keypress", event => {
  if (event.keyCode === 13) {
    login(channel, activate_user);
  }
});

$("#login-btn").on("click", event => {
  login(channel, activate_user);
});

$("#follow-btn").on("click", event => {
  follow(channel, $("#follow-user").val());
});

$("#tweet-textbox input").on("keypress", event => {
  if (event.keyCode === 13) {
    tweet(channel, USERNAME);
  }
});
$("#hashtag-input").on("keypress", event => {
  if (event.keyCode === 13) {
    queryHashTags(channel, $("#hashtag-input").val());
  }
});

$("#follow-user").on("keypress", event => {
  if (event.keyCode === 13) {
    follow(channel, $("#follow-user").val());
  }
});

$("#queryBtnHashtag").on("click", event => {
  queryHashTags(channel, $("#hashtag-input").val());
});
$("#queryMentions").on("click", event => {
  queryMentions(channel, USERNAME);
});
$("#querySubscribed").on("click", event => {
  querySubscribed(channel, USERNAME);
});

$("#queryOwnTweet").on("click", event => {
  queryOwnTweets(channel, USERNAME);
});

$("#deleteAccount").on("click", event => {
  deleteAccount(channel, USERNAME);
});

$("#go-back").on("click", event => {
  hide_query();
});
