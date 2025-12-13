defmodule LocalCafe.Orders do
  @moduledoc """
  The Orders context.

  Handles all business logic for orders including:
  - Creating and managing orders
  - Listing orders for users and admins
  - Status management
  - Cancellation
  """

  import Ecto.Query, warn: false
  alias LocalCafe.Repo

  alias LocalCafe.Orders.Order
  alias LocalCafe.Notifications
  alias LocalCafe.Accounts.User
  alias LocalCafe.Accounts.Scope

  require Logger

  @doc """
  Returns the list of orders.

  For admins: returns all orders
  For logged-in users: returns only their own orders
  For guests: returns empty list

  ## Examples

      iex> list_orders(scope)
      [%Order{}, ...]

  """
  def list_orders(%Scope{user: %{admin: true}}) do
    Order
    |> order_by([o], desc: o.inserted_at)
    |> preload(:line_items)
    |> Repo.all()
  end

  def list_orders(%Scope{user: user}) do
    Order
    |> where([o], o.user_id == ^user.id)
    |> order_by([o], desc: o.inserted_at)
    |> preload(:line_items)
    |> Repo.all()
  end

  def list_orders(_), do: []

  @doc """
  Gets a single order.

  For admins: can access any order
  For users: can only access their own orders

  Raises `Ecto.NoResultsError` if the order does not exist or user doesn't have access.

  ## Examples

      iex> get_order!(scope, "123")
      %Order{}

      iex> get_order!(scope, "456")
      ** (Ecto.NoResultsError)

  """
  def get_order!(%Scope{user: %{admin: true}}, id) do
    Order
    |> preload([:user, line_items: :menu_item])
    |> Repo.get!(id)
  end

  def get_order!(%Scope{user: user}, id) do
    Order
    |> where([o], o.user_id == ^user.id)
    |> preload([:user, line_items: :menu_item])
    |> Repo.get!(id)
  end

  def get_order!(_, _id) do
    raise Ecto.NoResultsError, queryable: Order
  end

  @doc """
  Gets a single order by ID without authorization checks.

  This is used for token-based guest access where the token itself
  provides authorization.

  ## Examples

      iex> get_order_by_id!("123")
      %Order{}

      iex> get_order_by_id!("456")
      ** (Ecto.NoResultsError)

  """
  def get_order_by_id!(id) do
    Order
    |> preload(line_items: :menu_item)
    |> Repo.get!(id)
  end

  @doc """
  Creates an order.

  Can be called by anyone (guests or logged-in users).

  ## Examples

      iex> create_order(scope, %{field: value})
      {:ok, %Order{}}

      iex> create_order(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_order(scope, attrs \\ %{}) do
    # Add user_id if logged in
    attrs =
      case scope do
        %Scope{user: %{id: user_id}} -> Map.put(attrs, :user_id, user_id)
        _ -> attrs
      end

    %Order{}
    |> Order.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an order's status.

  Admin only.

  ## Examples

      iex> update_order_status(admin_scope, order, "paid")
      {:ok, %Order{}}

      iex> update_order_status(admin_scope, order, "invalid")
      {:error, %Ecto.Changeset{}}

  """
  def update_order_status(%Scope{user: admin_user} = _scope, %Order{} = order, status) do
    old_status = order.status
    attrs = %{status: status}

    # Set completed_at when status changes to completed
    attrs =
      if status == "completed" and is_nil(order.completed_at) do
        Map.put(attrs, :completed_at, DateTime.utc_now())
      else
        attrs
      end

    # Set cancelled_at when status changes to cancelled
    attrs =
      if status == "cancelled" and is_nil(order.cancelled_at) do
        Map.put(attrs, :cancelled_at, DateTime.utc_now())
      else
        attrs
      end

    # Build changed_by info
    changed_by = %{
      id: Map.get(admin_user, :id),
      email: Map.get(admin_user, :email),
      admin: Map.get(admin_user, :admin, false)
    }

    with {:ok, updated_order} <-
           order
           |> Order.changeset(attrs)
           |> Order.append_status_event(status, changed_by)
           |> Repo.update() do
      # Create notification for user if status changed and order has a user
      if old_status != status and updated_order.user_id do
        create_order_status_notification(updated_order)
      end

      {:ok, updated_order}
    end
  end

  def update_order_status(_, _, _) do
    {:error, :unauthorized}
  end

  # Creates a notification for order status changes
  defp create_order_status_notification(%Order{} = order) do
    case Repo.get(User, order.user_id) do
      nil ->
        :ok

      user ->
        {title, body} = notification_content_for_status(order.status, order.order_number)

        case Notifications.notify_user(user, %{
               title: title,
               body: body,
               redirect_link: "/my-orders/#{order.id}"
             }) do
          {:ok, notification} ->
            {:ok, notification}

          {:error, changeset} ->
            Logger.error(
              "Failed to create notification for order #{order.order_number}: #{inspect(changeset.errors)}"
            )

            {:error, changeset}
        end
    end
  end

  # Returns notification title and body based on order status
  defp notification_content_for_status(status, order_number) do
    case status do
      "paid" ->
        {"Payment Confirmed", "Your order #{order_number} payment has been confirmed."}

      "preparing" ->
        {"Order in Progress", "Your order #{order_number} is being prepared."}

      "ready" ->
        {"Order Ready!", "Your order #{order_number} is ready for pickup."}

      "completed" ->
        {"Order Completed", "Your order #{order_number} has been completed. Thank you!"}

      "cancelled" ->
        {"Order Cancelled", "Your order #{order_number} has been cancelled."}

      _ ->
        {"Order Update", "Your order #{order_number} status has been updated."}
    end
  end

  @doc """
  Cancels an order.

  Users can cancel their own pending orders.
  Admins can cancel any order regardless of status.

  ## Examples

      iex> cancel_order(scope, order)
      {:ok, %Order{}}

  """
  def cancel_order(%Scope{user: %{admin: true}}, %Order{} = order) do
    update_order_status(%Scope{user: %{admin: true}}, order, "cancelled")
  end

  def cancel_order(%Scope{user: user}, %Order{user_id: user_id, status: "pending"} = order)
      when user.id == user_id do
    order
    |> Order.changeset(%{status: "cancelled", cancelled_at: DateTime.utc_now()})
    |> Repo.update()
  end

  def cancel_order(_, _) do
    {:error, :unauthorized}
  end

  @doc """
  Returns statistics for the admin dashboard.

  ## Examples

      iex> get_order_stats()
      %{total: 100, pending: 5, confirmed: 10, ...}

  """
  def get_order_stats do
    total = Repo.aggregate(Order, :count)

    status_counts =
      from(o in Order,
        group_by: o.status,
        select: {o.status, count(o.id)}
      )
      |> Repo.all()
      |> Enum.into(%{})

    %{
      total: total,
      pending: Map.get(status_counts, "pending", 0),
      paid: Map.get(status_counts, "paid", 0),
      preparing: Map.get(status_counts, "preparing", 0),
      ready: Map.get(status_counts, "ready", 0),
      completed: Map.get(status_counts, "completed", 0),
      cancelled: Map.get(status_counts, "cancelled", 0)
    }
  end
end
