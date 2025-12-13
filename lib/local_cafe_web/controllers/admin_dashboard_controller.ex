defmodule LocalCafeWeb.AdminDashboardController do
  use LocalCafeWeb, :controller
  alias LocalCafe.Accounts
  alias LocalCafe.Posts
  alias LocalCafe.Comments
  alias LocalCafe.Billing
  alias LocalCafe.Orders

  def index(conn, _params) do
    # Check if user is admin
    if conn.assigns.current_scope && conn.assigns.current_scope.user &&
         conn.assigns.current_scope.user.admin do
      scope = conn.assigns.current_scope

      # Fetch statistics from all contexts
      user_stats = Accounts.get_user_stats()
      post_stats = Posts.get_post_stats()
      comment_stats = Comments.get_comment_stats(scope)
      billing_stats = Billing.get_billing_stats()
      order_stats = Orders.get_order_stats()

      conn
      |> assign(:user_stats, user_stats)
      |> assign(:post_stats, post_stats)
      |> assign(:comment_stats, comment_stats)
      |> assign(:billing_stats, billing_stats)
      |> assign(:order_stats, order_stats)
      |> render(:index, page_title: "Admin Dashboard")
    else
      conn
      |> put_flash(:error, "You must be an admin to access this page.")
      |> redirect(to: ~p"/")
    end
  end
end
