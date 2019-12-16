defmodule TwitterWeb.PageController do
  use TwitterWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end

  def feed(conn, _params) do
    render(conn, "feed.html")
  end
end
