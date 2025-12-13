defmodule LocalCafeWeb.AdminOrdersController do
  use LocalCafeWeb, :controller

  alias LocalCafe.Orders

  @doc """
  List all orders (admin only).

  Handles GET /admin/orders
  """
  def index(conn, _params) do
    scope = conn.assigns.current_scope
    orders = Orders.list_orders(scope)
    stats = Orders.get_order_stats()

    render(conn, :index,
      orders: orders,
      stats: stats,
      page_title: "Manage Orders"
    )
  end

  @doc """
  Show a specific order with full details (admin only).

  Handles GET /admin/orders/:id
  """
  def show(conn, %{"id" => id}) do
    alias LocalCafe.Billing

    scope = conn.assigns.current_scope
    order = Orders.get_order!(scope, id)
    payment = Billing.get_payment_by_order(order.id)

    render(conn, :show,
      order: order,
      payment: payment,
      page_title: "Order #{order.order_number}"
    )
  end

  @doc """
  Update an order's status (admin only).

  Handles POST /admin/orders/:id/update-status
  """
  def update_status(conn, %{"id" => id, "status" => status}) do
    scope = conn.assigns.current_scope
    order = Orders.get_order!(scope, id)

    case Orders.update_order_status(scope, order, status) do
      {:ok, order} ->
        conn
        |> put_flash(:info, "Order status updated to #{status}.")
        |> redirect(to: ~p"/admin/orders/#{order}")

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "You are not authorized to update this order.")
        |> redirect(to: ~p"/admin/orders")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Unable to update order status. Please try again.")
        |> redirect(to: ~p"/admin/orders/#{order}")
    end
  end

  @doc """
  Refund an order's payment (admin only).

  Handles POST /admin/orders/:id/refund
  """
  def refund(conn, %{"id" => id}) do
    alias LocalCafe.Billing

    scope = conn.assigns.current_scope
    order = Orders.get_order!(scope, id)

    case Billing.process_refund(order, reason: :requested_by_customer) do
      {:ok, payment} ->
        # Update order status to refunded if payment is fully refunded
        updated_order =
          if Billing.Payment.fully_refunded?(payment) do
            case Orders.update_order_status(scope, order, "refunded") do
              {:ok, refunded_order} ->
                refunded_order

              {:error, _reason} ->
                # Log error but don't fail the refund - webhook will retry
                require Logger

                Logger.warning(
                  "Refund succeeded but failed to update order #{order.order_number} status"
                )

                order
            end
          else
            order
          end

        conn
        |> put_flash(
          :info,
          "Order #{order.order_number} has been successfully refunded. Status updated to refunded."
        )
        |> redirect(to: ~p"/admin/orders/#{updated_order}")

      {:error, :no_payment} ->
        conn
        |> put_flash(:error, "No payment found for this order.")
        |> redirect(to: ~p"/admin/orders/#{order}")

      {:error, :payment_not_succeeded} ->
        conn
        |> put_flash(:error, "Cannot refund: payment has not succeeded yet.")
        |> redirect(to: ~p"/admin/orders/#{order}")

      {:error, :already_refunded} ->
        conn
        |> put_flash(:error, "This order has already been fully refunded.")
        |> redirect(to: ~p"/admin/orders/#{order}")

      {:error, %Stripe.Error{} = error} ->
        conn
        |> put_flash(:error, "Stripe error: #{error.message}")
        |> redirect(to: ~p"/admin/orders/#{order}")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Failed to process refund. Please try again or check Stripe dashboard.")
        |> redirect(to: ~p"/admin/orders/#{order}")
    end
  end
end
