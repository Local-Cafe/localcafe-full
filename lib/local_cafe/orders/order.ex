defmodule LocalCafe.Orders.Order do
  @moduledoc """
  Schema for orders.

  An order contains multiple line items and tracks:
  - Order number (unique identifier)
  - Status (pending → paid → preparing → ready → completed/cancelled)
  - Customer information (user or guest)
  - Total amount
  - Timestamps for completion/cancellation
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias LocalCafe.Orders.OrderLineItem
  alias LocalCafe.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "orders" do
    field :order_number, :string
    field :status, :string, default: "pending"
    field :subtotal, :integer
    field :customer_note, :string
    field :customer_name, :string
    field :customer_email, :string
    field :completed_at, :utc_datetime
    field :cancelled_at, :utc_datetime
    field :status_events, {:array, :map}, default: []

    belongs_to :user, User
    has_many :line_items, OrderLineItem, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @valid_statuses ~w(pending paid preparing ready completed cancelled refunded)

  @doc false
  def changeset(order, attrs) do
    order
    |> cast(attrs, [:status, :customer_note, :customer_name, :customer_email, :user_id])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_format(:customer_email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    |> cast_assoc(:line_items, with: &OrderLineItem.changeset/2)
    |> calculate_subtotal()
    |> generate_order_number()
  end

  defp calculate_subtotal(changeset) do
    case get_change(changeset, :line_items) do
      nil ->
        changeset

      line_items ->
        subtotal =
          Enum.reduce(line_items, 0, fn item, acc ->
            case get_field(item, :subtotal) do
              nil -> acc
              amount -> acc + amount
            end
          end)

        put_change(changeset, :subtotal, subtotal)
    end
  end

  defp generate_order_number(changeset) do
    if get_field(changeset, :order_number) do
      changeset
    else
      date_str = Date.utc_today() |> Date.to_iso8601() |> String.replace("-", "")
      # Use microsecond timestamp for uniqueness
      seq =
        :os.system_time(:microsecond)
        |> rem(10000)
        |> Integer.to_string()
        |> String.pad_leading(4, "0")

      order_num = "ORD-#{date_str}-#{seq}"
      put_change(changeset, :order_number, order_num)
    end
  end

  @doc """
  Appends a status change event to the order's event history.

  ## Parameters
    * `changeset_or_order` - The order struct or changeset
    * `new_status` - The new status
    * `changed_by` - Map with user info: %{id: user_id, email: email, admin: boolean}

  ## Example
      iex> append_status_event(order, "preparing", %{id: "123", email: "admin@example.com", admin: true})
      %Ecto.Changeset{}
  """
  def append_status_event(%Ecto.Changeset{} = changeset, new_status, changed_by) do
    # Get the order data from the changeset
    order = changeset.data

    event = %{
      from_status: order.status,
      to_status: new_status,
      changed_by: changed_by,
      changed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    existing_events = order.status_events || []
    new_events = existing_events ++ [event]

    put_change(changeset, :status_events, new_events)
  end

  def append_status_event(order, new_status, changed_by) do
    event = %{
      from_status: order.status,
      to_status: new_status,
      changed_by: changed_by,
      changed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    existing_events = order.status_events || []
    new_events = existing_events ++ [event]

    change(order, status_events: new_events)
  end
end
