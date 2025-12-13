defmodule LocalCafe.Notifications do
  @moduledoc """
  The Notifications context.
  """

  import Ecto.Query, warn: false
  alias LocalCafe.Repo
  alias LocalCafe.Notifications.Notification
  alias LocalCafe.Notifications.PushSubscription
  alias LocalCafe.Accounts.User

  @doc """
  Returns the list of notifications for a user.
  """
  def list_user_notifications(%User{} = user) do
    Notification
    |> where([n], n.user_id == ^user.id)
    |> order_by([n], desc: n.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the list of unread notifications for a user.
  """
  def list_unread_notifications(%User{} = user) do
    Notification
    |> where([n], n.user_id == ^user.id and is_nil(n.viewed_at))
    |> order_by([n], desc: n.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets the count of unread notifications for a user.
  """
  def count_unread_notifications(%User{} = user) do
    Notification
    |> where([n], n.user_id == ^user.id and is_nil(n.viewed_at))
    |> Repo.aggregate(:count)
  end

  @doc """
  Gets a single notification.

  Raises `Ecto.NoResultsError` if the Notification does not exist.
  """
  def get_notification!(id), do: Repo.get!(Notification, id)

  @doc """
  Gets a notification for a specific user.

  Raises `Ecto.NoResultsError` if the Notification does not exist or doesn't belong to the user.
  """
  def get_user_notification!(user_id, id) do
    Notification
    |> where([n], n.id == ^id and n.user_id == ^user_id)
    |> Repo.one!()
  end

  @doc """
  Creates a notification.

  ## Examples

      iex> create_notification(%{field: value})
      {:ok, %Notification{}}

      iex> create_notification(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_notification(attrs \\ %{}) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a notification for a user.
  """
  def create_user_notification(%User{} = user, attrs) do
    attrs = Map.put(attrs, :user_id, user.id)
    create_notification(attrs)
  end

  @doc """
  Creates a notification for a user and sends a push notification.
  """
  def notify_user(%User{} = user, attrs) do
    with {:ok, notification} <- create_user_notification(user, attrs) do
      # Send push notification in the background
      Task.start(fn ->
        alias LocalCafe.Notifications.PushNotifier

        PushNotifier.send_to_user(user,
          title: notification.title,
          body: notification.body,
          redirect_link: notification.redirect_link
        )
      end)

      {:ok, notification}
    end
  end

  @doc """
  Marks a notification as viewed.
  """
  def mark_as_viewed(%Notification{} = notification) do
    notification
    |> Notification.mark_as_viewed_changeset()
    |> Repo.update()
  end

  @doc """
  Marks all notifications as viewed for a user.
  """
  def mark_all_as_viewed(%User{} = user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Notification
    |> where([n], n.user_id == ^user.id and is_nil(n.viewed_at))
    |> Repo.update_all(set: [viewed_at: now, updated_at: now])
  end

  @doc """
  Deletes a notification.
  """
  def delete_notification(%Notification{} = notification) do
    Repo.delete(notification)
  end

  @doc """
  Deletes all notifications for a user.
  """
  def delete_all_notifications(%User{} = user) do
    Notification
    |> where([n], n.user_id == ^user.id)
    |> Repo.delete_all()
  end

  # Push Subscriptions

  @doc """
  Creates or updates a push subscription for a user.
  """
  def subscribe_to_push(%User{} = user, subscription_params) do
    attrs = %{
      user_id: user.id,
      endpoint: subscription_params["endpoint"],
      p256dh_key: get_in(subscription_params, ["keys", "p256dh"]),
      auth_key: get_in(subscription_params, ["keys", "auth"])
    }

    # Try to find existing subscription by endpoint
    case Repo.get_by(PushSubscription, endpoint: attrs.endpoint) do
      nil ->
        %PushSubscription{}
        |> PushSubscription.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> PushSubscription.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Removes a push subscription.
  """
  def unsubscribe_from_push(endpoint) do
    case Repo.get_by(PushSubscription, endpoint: endpoint) do
      nil -> {:error, :not_found}
      subscription -> Repo.delete(subscription)
    end
  end

  @doc """
  Gets all push subscriptions for a user.
  """
  def list_user_subscriptions(%User{} = user) do
    PushSubscription
    |> where([s], s.user_id == ^user.id)
    |> Repo.all()
  end
end
