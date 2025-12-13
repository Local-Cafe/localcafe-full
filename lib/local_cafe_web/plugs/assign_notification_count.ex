defmodule LocalCafeWeb.Plugs.AssignNotificationCount do
  @moduledoc """
  Assigns the count of unread notifications to the connection for the current user.
  """
  import Plug.Conn
  alias LocalCafe.Notifications

  def init(opts), do: opts

  def call(conn, _opts) do
    notification_count =
      if conn.assigns[:current_scope] && conn.assigns.current_scope.user do
        Notifications.count_unread_notifications(conn.assigns.current_scope.user)
      else
        0
      end

    assign(conn, :notification_count, notification_count)
  end
end
