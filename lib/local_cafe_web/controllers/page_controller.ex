defmodule LocalCafeWeb.PageController do
  use LocalCafeWeb, :controller

  alias LocalCafe.Posts

  def home(conn, _params) do
    title = "Welcome to LocalCafe.org"
    scope = conn.assigns.current_scope
    latest_posts = Posts.get_latest_posts(scope, 3)

    render(conn, :home,
      latest_posts: latest_posts,
      title: title,
      page_title: "Home",
      page_description: "LocalCafe.org - A full featured site for restaurants and cafes"
    )
  end
end
