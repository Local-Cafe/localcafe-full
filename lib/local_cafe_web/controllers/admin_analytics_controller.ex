defmodule LocalCafeWeb.AdminAnalyticsController do
  use LocalCafeWeb, :controller

  def index(conn, _params) do
    # Check if user is admin
    if conn.assigns.current_scope && conn.assigns.current_scope.user &&
         conn.assigns.current_scope.user.admin do
      user = conn.assigns.current_scope.user
      # Generate token for socket authentication
      token = Phoenix.Token.sign(conn, "user socket", user.id)

      conn
      |> assign(:user_token, token)
      |> render(:index, page_title: "Admin - Analytics")
    else
      conn
      |> put_flash(:error, "You must be an admin to access this page.")
      |> redirect(to: ~p"/")
    end
  end
end
