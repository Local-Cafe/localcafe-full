defmodule LocalCafeWeb.CommentController do
  use LocalCafeWeb, :controller

  alias LocalCafe.Posts
  alias LocalCafe.Posts.Comments

  def create(conn, %{"slug" => slug, "comment" => comment_params}) do
    post = Posts.get_post!(conn.assigns.current_scope, slug)
    user = conn.assigns.current_scope.user

    # Require name before allowing comments
    if is_nil(user.name) || user.name == "" do
      conn
      |> put_flash(
        :error,
        "You must set a name before commenting. Please update your settings."
      )
      |> redirect(to: ~p"/users/settings")
    else
      create_comment_for_post(conn, post, slug, comment_params)
    end
  end

  defp create_comment_for_post(conn, post, slug, comment_params) do
    user = conn.assigns.current_scope.user

    case Comments.create_comment(conn.assigns.current_scope, post.id, comment_params) do
      {:ok, comment} ->
        # Trusted users' comments are auto-approved, so redirect to the comment
        if user.trusted || user.admin do
          conn
          |> put_flash(:info, "Comment added successfully.")
          |> redirect(to: ~p"/posts/#{slug}" <> "#comment-#{comment.id}")
        else
          conn
          |> put_flash(:info, "Comment added successfully. It will appear once approved.")
          |> redirect(to: ~p"/posts/#{slug}")
        end

      {:error, %Ecto.Changeset{} = _changeset} ->
        conn
        |> put_flash(:error, "Error creating comment. Please try again.")
        |> redirect(to: ~p"/posts/#{slug}")
    end
  end

  def approve(conn, %{"id" => id}) do
    referer = get_req_header(conn, "referer") |> List.first() || ~p"/admin/comments"

    case Comments.approve_comment(conn.assigns.current_scope, id) do
      {:ok, _comment} ->
        conn
        |> put_flash(:info, "Comment approved successfully.")
        |> redirect(external: referer)

      {:error, _} ->
        conn
        |> put_flash(:error, "Error approving comment.")
        |> redirect(external: referer)
    end
  end

  def delete(conn, %{"id" => id}) do
    referer = get_req_header(conn, "referer") |> List.first() || ~p"/admin/comments"

    case Comments.delete_comment(conn.assigns.current_scope, id) do
      {:ok, _comment} ->
        conn
        |> put_flash(:info, "Comment deleted successfully.")
        |> redirect(external: referer)

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "You are not authorized to delete this comment.")
        |> redirect(external: referer)

      {:error, _} ->
        conn
        |> put_flash(:error, "Error deleting comment.")
        |> redirect(external: referer)
    end
  end
end
