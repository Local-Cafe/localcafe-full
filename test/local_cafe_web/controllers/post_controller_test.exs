defmodule LocalCafeWeb.PostControllerTest do
  use LocalCafeWeb.ConnCase

  import LocalCafe.PostsFixtures

  @create_attrs %{
    description: "some description",
    title: "some title",
    body: "some body content with enough characters",
    slug: "some-slug",
    published_at: ~D[2025-10-27],
    draft: true
  }
  @update_attrs %{
    description: "some updated description",
    title: "some updated title",
    body: "some updated body content with enough characters",
    slug: "some-updated-slug",
    published_at: ~D[2025-10-28],
    draft: false
  }
  @invalid_attrs %{
    description: nil,
    title: nil,
    body: nil,
    slug: nil,
    published_at: nil,
    draft: nil
  }

  setup :register_and_log_in_admin

  describe "index" do
    test "lists all posts", %{conn: conn} do
      conn = get(conn, ~p"/posts")
      assert html_response(conn, 200) =~ "New Post"
    end
  end

  describe "new post" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/posts/new")
      assert html_response(conn, 200) =~ "New Post"
    end
  end

  describe "create post" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, ~p"/posts", post: @create_attrs)

      assert %{slug: slug} = redirected_params(conn)
      assert redirected_to(conn) == ~p"/posts/#{slug}"

      conn = get(conn, ~p"/posts/#{slug}")
      assert html_response(conn, 200) =~ @create_attrs.title
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, ~p"/posts", post: @invalid_attrs)
      assert html_response(conn, 200) =~ "New Post"
    end
  end

  describe "edit post" do
    setup [:create_post]

    test "renders form for editing chosen post", %{conn: conn, post: post} do
      conn = get(conn, ~p"/posts/#{post}/edit")
      assert html_response(conn, 200) =~ "Edit Post"
    end
  end

  describe "update post" do
    setup [:create_post]

    test "redirects when data is valid", %{conn: conn, post: post} do
      conn = put(conn, ~p"/posts/#{post}", post: @update_attrs)
      # After update, the slug will have changed to the new slug
      assert redirected_to(conn) == ~p"/posts/#{@update_attrs.slug}"

      conn = get(conn, ~p"/posts/#{@update_attrs.slug}")
      assert html_response(conn, 200) =~ "some updated title"
    end

    test "renders errors when data is invalid", %{conn: conn, post: post} do
      conn = put(conn, ~p"/posts/#{post}", post: @invalid_attrs)
      assert html_response(conn, 200) =~ "Edit Post"
    end
  end

  describe "delete post" do
    setup [:create_post]

    test "deletes chosen post", %{conn: conn, post: post} do
      conn = delete(conn, ~p"/posts/#{post}")
      assert redirected_to(conn) == ~p"/posts"

      assert_error_sent 404, fn ->
        get(conn, ~p"/posts/#{post}")
      end
    end
  end

  defp create_post(%{scope: scope}) do
    post = post_fixture(scope)

    %{post: post}
  end
end
