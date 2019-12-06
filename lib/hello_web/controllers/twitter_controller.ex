defmodule HelloWeb.TwitterController do
  use HelloWeb, :controller

  def index(conn, _params) do
    render(conn, "twitter.html")
  end
end
