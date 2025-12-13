defmodule LocalCafeWeb.AdminCommentsController do
  use LocalCafeWeb, :controller
  alias LocalCafe.Comments

  def index(conn, params) do
    # Check if user is admin
    if conn.assigns.current_scope && conn.assigns.current_scope.user &&
         conn.assigns.current_scope.user.admin do
      scope = conn.assigns.current_scope

      # Get filter and user_id parameters
      filter = Map.get(params, "filter", "pending")
      user_id = Map.get(params, "user_id")

      # Get comments based on user_id or filter
      comments =
        cond do
          user_id ->
            Comments.list_comments_by_user(scope, user_id)

          filter == "pending" ->
            Comments.list_pending_comments(scope)

          filter == "approved" ->
            Comments.list_approved_comments(scope)

          filter == "all" ->
            Comments.list_all_comments(scope)

          true ->
            Comments.list_pending_comments(scope)
        end

      render(conn, :index,
        comments: comments,
        filter: filter,
        user_id: user_id,
        page_title: "Admin - Comments"
      )
    else
      conn
      |> put_flash(:error, "You must be an admin to access this page.")
      |> redirect(to: ~p"/")
    end
  end
end
