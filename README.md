## Twitter Clone

A high-performing and scalable Twitter-clone with the backend engine server designed in Elixir; 
Used the Phoenix framework to connect the associated web interface built in Javascript and html/css.

### Commands to get the server running:

1. cd assets && npm install && cd ..

2. mix deps.get

3. mix phx.server

4. Point your browser to http://localhost:4000/ and benefit!

### Functionalities Implemented:

1. Register a new user account
2. Login and logout user
3. Delete account
4. Tweeting of the following types:
    a. Simple tweet
    b. Tweet with hashtags
    c. Tweet with mentions (other users)
    d. Retweet (They are visible in a different color than the rest
       for easy identification)
    e. Any permutation and combination of the above scenarios
5. Follow users and subscribe to their tweets
6. Query to followings:
    a. Tweets by subscribed (following) users.
    b. Tweets with hashtags
    c. Tweets with own mentions.
7. Live distribution of tweets when a user is online (tweets from subscribed users or tweets where
    the user is mentioned).

