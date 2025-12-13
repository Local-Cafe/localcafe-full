defmodule LocalCafeWeb.AdminUsersController do
  use LocalCafeWeb, :controller
  alias LocalCafe.Accounts
  alias LocalCafe.Comments

  def index(conn, params) do
    # Check if user is admin
    if conn.assigns.current_scope && conn.assigns.current_scope.user &&
         conn.assigns.current_scope.user.admin do
      scope = conn.assigns.current_scope

      # Get filter parameter (default to "all")
      filter = Map.get(params, "filter", "all")

      # Get users based on filter
      users =
        case filter do
          "admin" -> Accounts.list_admin_users()
          "trusted" -> Accounts.list_trusted_users()
          "regular" -> Accounts.list_regular_users()
          "all" -> Accounts.list_all_users()
          _ -> Accounts.list_all_users()
        end

      # Add comment counts to each user
      users_with_counts =
        Enum.map(users, fn user ->
          comment_count = Comments.count_comments_by_user(scope, user.id)
          Map.put(user, :comment_count, comment_count)
        end)

      render(conn, :index, users: users_with_counts, filter: filter, page_title: "Admin - Users")
    else
      conn
      |> put_flash(:error, "You must be an admin to access this page.")
      |> redirect(to: ~p"/")
    end
  end

  def toggle_admin(conn, %{"id" => user_id}) do
    if conn.assigns.current_scope && conn.assigns.current_scope.user &&
         conn.assigns.current_scope.user.admin do
      current_user = conn.assigns.current_scope.user

      # Prevent user from removing their own admin status
      if current_user.id == user_id do
        conn
        |> put_flash(:error, "You cannot remove your own admin status.")
        |> redirect(to: ~p"/admin/users")
      else
        user = Accounts.get_user!(user_id)
        {:ok, _user} = Accounts.toggle_admin(user)

        conn
        |> put_flash(:info, "User admin status updated.")
        |> redirect(to: ~p"/admin/users")
      end
    else
      conn
      |> put_flash(:error, "You must be an admin to access this page.")
      |> redirect(to: ~p"/")
    end
  end

  def toggle_trusted(conn, %{"id" => user_id}) do
    if conn.assigns.current_scope && conn.assigns.current_scope.user &&
         conn.assigns.current_scope.user.admin do
      user = Accounts.get_user!(user_id)
      {:ok, _user} = Accounts.toggle_trusted(user)

      conn
      |> put_flash(:info, "User trusted status updated.")
      |> redirect(to: ~p"/admin/users")
    else
      conn
      |> put_flash(:error, "You must be an admin to access this page.")
      |> redirect(to: ~p"/")
    end
  end
end
