defmodule LocalCafeWeb.NotificationController do
  use LocalCafeWeb, :controller

  alias LocalCafe.Notifications

  plug :require_authenticated_user

  def index(conn, _params) do
    user = conn.assigns.current_scope.user
    notifications = Notifications.list_user_notifications(user)

    render(conn, :index,
      notifications: notifications,
      page_title: "Notifications"
    )
  end

  def mark_as_viewed(conn, %{"id" => id}) do
    user = conn.assigns.current_scope.user

    notification = Notifications.get_user_notification!(user.id, id)
    {:ok, _notification} = Notifications.mark_as_viewed(notification)

    # Redirect to the notification's redirect_link
    redirect(conn, to: notification.redirect_link)
  end

  def mark_all_as_viewed(conn, _params) do
    user = conn.assigns.current_scope.user
    Notifications.mark_all_as_viewed(user)

    conn
    |> put_flash(:info, "All notifications marked as read")
    |> redirect(to: ~p"/notifications")
  end

  def delete_all(conn, _params) do
    user = conn.assigns.current_scope.user
    {count, _} = Notifications.delete_all_notifications(user)

    conn
    |> put_flash(:info, "Deleted #{count} notification#{if count == 1, do: "", else: "s"}")
    |> redirect(to: ~p"/notifications")
  end

  # API endpoint to get notification count
  def count(conn, _params) do
    user = conn.assigns.current_scope.user
    count = Notifications.count_unread_notifications(user)

    json(conn, %{count: count})
  end

  # API endpoints for push subscriptions
  def subscribe(conn, %{"subscription" => subscription_params}) do
    user = conn.assigns.current_scope.user

    case Notifications.subscribe_to_push(user, subscription_params) do
      {:ok, _subscription} ->
        json(conn, %{success: true})

      {:error, _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{success: false, error: "Failed to create subscription"})
    end
  end

  def unsubscribe(conn, %{"endpoint" => endpoint}) do
    case Notifications.unsubscribe_from_push(endpoint) do
      {:ok, _subscription} ->
        json(conn, %{success: true})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{success: false, error: "Subscription not found"})
    end
  end

  defp require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_scope] && conn.assigns.current_scope.user do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access notifications")
      |> redirect(to: ~p"/users/log-in")
      |> halt()
    end
  end
end
