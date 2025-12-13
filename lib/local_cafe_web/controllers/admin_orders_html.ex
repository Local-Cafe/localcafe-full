defmodule LocalCafeWeb.AdminOrdersHTML do
  use LocalCafeWeb, :html

  # Reuse helper functions from OrderHTML
  alias LocalCafeWeb.OrderHTML

  defdelegate format_price(cents), to: OrderHTML
  defdelegate format_status(status), to: OrderHTML
  defdelegate status_class(status), to: OrderHTML
  defdelegate format_datetime(datetime), to: OrderHTML

  alias LocalCafe.Billing.Payment

  embed_templates "admin_orders_html/*"

  @doc """
  Returns all valid order statuses for the status update form.
  Format: {label, value} for Phoenix.HTML.Form.options_for_select/2
  """
  def order_statuses do
    [
      {"Pending", "pending"},
      {"Paid", "paid"},
      {"Preparing", "preparing"},
      {"Ready", "ready"},
      {"Completed", "completed"},
      {"Cancelled", "cancelled"},
      {"Refunded", "refunded"}
    ]
  end

  @doc """
  Renders an order table row for the admin orders list.

  ## Examples

      <.admin_order_row order={@order} />
  """
  attr :order, :map, required: true

  def admin_order_row(assigns) do
    ~H"""
    <tr class="admin-order-row">
      <td>
        <a href={~p"/admin/orders/#{@order}"} class="order-number-link">
          {@order.order_number}
        </a>
      </td>
      <td>
        <span class={"order-status " <> status_class(@order.status)}>
          {format_status(@order.status)}
        </span>
      </td>
      <td>{format_datetime(@order.inserted_at)}</td>
      <td>
        <%= if @order.user_id do %>
          <span class="customer-type">Registered User</span>
        <% else %>
          {@order.customer_name}<br />
          <span class="customer-email">{@order.customer_email}</span>
        <% end %>
      </td>
      <td class="order-total">{format_price(@order.subtotal)}</td>
      <td>
        <.button href={~p"/admin/orders/#{@order}"} variant="secondary">
          View
        </.button>
      </td>
    </tr>
    """
  end

  @doc """
  Formats a payment status for display.
  """
  def format_payment_status(status) do
    case status do
      "succeeded" -> "Succeeded"
      "payment_intent.succeeded" -> "Succeeded"
      "charge.succeeded" -> "Succeeded"
      "charge.refunded" -> "Refunded"
      "requires_payment_method" -> "Requires Payment Method"
      "requires_confirmation" -> "Requires Confirmation"
      "requires_action" -> "Requires Action"
      "processing" -> "Processing"
      "canceled" -> "Canceled"
      _ -> String.capitalize(String.replace(status, "_", " "))
    end
  end

  @doc """
  Returns CSS class for payment status badge.
  """
  def payment_status_class(status) do
    case status do
      s when s in ["succeeded", "payment_intent.succeeded", "charge.succeeded"] ->
        "payment-status-succeeded"

      "charge.refunded" ->
        "payment-status-refunded"

      s when s in ["processing", "requires_action", "requires_confirmation"] ->
        "payment-status-processing"

      "canceled" ->
        "payment-status-canceled"

      _ ->
        "payment-status-default"
    end
  end

  @doc """
  Checks if a payment can be refunded.
  Returns true if the payment has succeeded and hasn't been fully refunded yet.
  """
  def payment_can_be_refunded?(payment) do
    Payment.succeeded?(payment) and not Payment.fully_refunded?(payment)
  end
end
