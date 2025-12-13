defmodule LocalCafeWeb.Plugs.RequireOrderAccess do
  @moduledoc """
  Ensures the user has access to view an order.

  Access is granted if EITHER:
  - The user is authenticated (via session), OR
  - A valid order view token is provided in the query params
  """

  import Plug.Conn
  import Phoenix.Controller
  use LocalCafeWeb, :verified_routes

  def init(opts), do: opts

  def call(conn, _opts) do
    cond do
      # User is authenticated - allow access
      conn.assigns[:current_scope] && conn.assigns.current_scope.user ->
        conn

      # Check for valid token
      has_valid_token?(conn) ->
        conn

      # No authentication and no valid token - redirect to login
      true ->
        conn
        |> put_flash(:error, "You must be logged in to view this order.")
        |> redirect(to: ~p"/users/log-in")
        |> halt()
    end
  end

  defp has_valid_token?(conn) do
    with %{"token" => token, "id" => order_id} <- conn.params,
         {:ok, token_order_id} <- Phoenix.Token.verify(conn, "order_view", token, max_age: 86400) do
      # Token is valid and matches the order ID
      to_string(token_order_id) == order_id
    else
      _ -> false
    end
  end
end
