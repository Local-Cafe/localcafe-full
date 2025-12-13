defmodule LocalCafe.Notifications.PushNotifier do
  @moduledoc """
  Sends Web Push notifications to subscribed users.

  Uses VAPID keys for authentication. Generate keys with:

      mix phx.gen.vapid

  Or manually:

      iex> :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  """

  alias LocalCafe.Notifications
  alias LocalCafe.Accounts.User
  require Logger

  @doc """
  Sends a push notification to all of a user's subscribed devices.

  ## Options
    * `:title` - Notification title (required)
    * `:body` - Notification body (required)
    * `:redirect_link` - Path to redirect to when notification is clicked (required)

  ## Examples

      iex> send_to_user(user, title: "New Order", body: "You have a new order", redirect_link: "/my-orders/123")
      {:ok, 2}  # Successfully sent to 2 subscriptions

  """
  def send_to_user(%User{} = user, opts) do
    title = Keyword.fetch!(opts, :title)
    body = Keyword.fetch!(opts, :body)
    redirect_link = Keyword.fetch!(opts, :redirect_link)

    payload = %{
      title: title,
      body: body,
      redirect_link: redirect_link,
      icon: "/images/icon-192.png",
      badge: "/images/badge-72.png"
    }

    subscriptions = Notifications.list_user_subscriptions(user)

    results =
      subscriptions
      |> Enum.map(fn subscription ->
        send_push(subscription, payload)
      end)

    success_count = Enum.count(results, fn result -> match?({:ok, _}, result) end)
    {:ok, success_count}
  end

  @doc """
  Sends a push notification to a specific subscription.
  """
  def send_push(subscription, payload) do
    # Build the subscription object expected by WebPushEncryption
    web_push_subscription = %{
      endpoint: subscription.endpoint,
      keys: %{
        p256dh: subscription.p256dh_key,
        auth: subscription.auth_key
      }
    }

    # Encode payload as JSON
    encoded_payload = Jason.encode!(payload)

    # Send the push notification
    # VAPID details are configured in config/runtime.exs under :web_push_encryption
    case WebPushEncryption.send_web_push(
           encoded_payload,
           web_push_subscription
         ) do
      {:ok, _response} ->
        {:ok, subscription}

      {:error, reason} ->
        Logger.error("Failed to send push notification: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
