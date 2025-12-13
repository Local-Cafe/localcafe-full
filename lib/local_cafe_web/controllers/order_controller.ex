defmodule LocalCafeWeb.OrderController do
  use LocalCafeWeb, :controller

  alias LocalCafe.Menu
  alias LocalCafe.Orders

  @doc """
  Create an order from a menu item.

  Handles POST /menu/:slug/order
  Accessible to all users (guests and authenticated)
  """
  def create(conn, %{"slug" => slug, "order" => order_params}) do
    scope = conn.assigns.current_scope

    # Get the menu item to create order from
    menu_item = Menu.get_menu_item!(scope, slug)

    # Parse the order data and build line item
    order_attrs = build_order_attrs(order_params, menu_item)

    case Orders.create_order(scope, order_attrs) do
      {:ok, order} ->
        conn
        |> put_flash(:info, "Order placed successfully! Order number: #{order.order_number}")
        |> redirect(to: order_redirect_path(conn, order))

      {:error, %Ecto.Changeset{}} ->
        # Re-render the menu item page with errors
        conn
        |> put_flash(:error, "Unable to place order. Please check the form and try again.")
        |> redirect(to: ~p"/menu/#{slug}")
    end
  end

  @doc """
  List all orders for the current user.

  Handles GET /my-orders
  Requires authentication
  """
  def index(conn, _params) do
    scope = conn.assigns.current_scope
    orders = Orders.list_orders(scope)

    render(conn, :index,
      orders: orders,
      page_title: "My Orders"
    )
  end

  @doc """
  Show a specific order.

  Handles GET /my-orders/:id
  Handles GET /my-orders/:id?token=...

  Authorization is handled by the RequireOrderAccess plug.
  This action assumes the request is already authorized.
  """
  def show(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope

    # If user is authenticated, use scope-based authorization
    # Otherwise, fetch order directly (token was validated by plug)
    order =
      if scope && scope.user do
        Orders.get_order!(scope, id)
      else
        Orders.get_order_by_id!(id)
      end

    render(conn, :show,
      order: order,
      page_title: "Order #{order.order_number}"
    )
  end

  @doc """
  Cancel a pending order.

  Handles POST /my-orders/:id/cancel
  Requires authentication and ownership
  """
  def cancel(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope
    order = Orders.get_order!(scope, id)

    case Orders.cancel_order(scope, order) do
      {:ok, order} ->
        conn
        |> put_flash(:info, "Order #{order.order_number} has been cancelled.")
        |> redirect(to: ~p"/my-orders/#{order}")

      {:error, :unauthorized} ->
        conn
        |> put_flash(:error, "You are not authorized to cancel this order.")
        |> redirect(to: ~p"/my-orders")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Unable to cancel order. Please try again.")
        |> redirect(to: ~p"/my-orders/#{order}")
    end
  end

  # Private helper functions

  defp build_order_attrs(order_params, menu_item) do
    # Extract selected price index
    price_index = String.to_integer(order_params["price_index"] || "0")
    selected_price = Enum.at(menu_item.prices, price_index)

    # Extract selected variant indices (if any)
    selected_variant_indices =
      case order_params["variant_indices"] do
        nil ->
          []

        "" ->
          []

        indices when is_binary(indices) ->
          String.split(indices, ",") |> Enum.map(&String.to_integer/1)

        indices when is_list(indices) ->
          Enum.map(indices, &String.to_integer/1)
      end

    selected_variants =
      selected_variant_indices
      |> Enum.map(fn idx -> Enum.at(menu_item.variants, idx) end)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(fn variant ->
        %{
          name: variant.name,
          price: variant.price
        }
      end)

    # Build line item with snapshot data
    line_item_attrs = %{
      menu_item_id: menu_item.id,
      item_title: menu_item.title,
      item_description: menu_item.description,
      base_price_label: selected_price.label,
      base_price_amount: selected_price.amount,
      selected_variants: selected_variants,
      customer_note: order_params["line_item_note"],
      position: 0
    }

    # Build order attributes
    %{
      customer_note: order_params["customer_note"],
      customer_name: order_params["customer_name"],
      customer_email: order_params["customer_email"],
      line_items: [line_item_attrs]
    }
  end

  defp order_redirect_path(conn, order) do
    # If user is authenticated, redirect to my-orders
    # If guest, redirect back to menu (they can't view their order)
    case conn.assigns.current_scope do
      %{user: _user} -> ~p"/my-orders/#{order}"
      _ -> ~p"/#menu"
    end
  end
end
