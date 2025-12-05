defmodule LocalCafeWeb.UserSocket do
  use Phoenix.Socket

  # Channels
  channel "analytics:*", LocalCafeWeb.AnalyticsChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    # Verify the token and get user
    case Phoenix.Token.verify(socket, "user socket", token, max_age: 86400) do
      {:ok, user_id} ->
        user = LocalCafe.Accounts.get_user!(user_id)

        if user.admin do
          {:ok, assign(socket, :current_user, user)}
        else
          :error
        end

      {:error, _reason} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.current_user.id}"
end
