defmodule LocalCafeWeb.Plugs.AssignHasBlogPosts do
  @moduledoc """
  Plug to assign has_blog_posts boolean to conn for use in layouts and templates.
  """
  import Plug.Conn
  alias LocalCafe.Posts

  def init(opts), do: opts

  def call(conn, _opts) do
    has_blog_posts = Posts.has_published_posts?()
    assign(conn, :has_blog_posts, has_blog_posts)
  end
end
