defmodule LocalCafeWeb.CartController do
  use LocalCafeWeb, :controller

  alias LocalCafe.{Repo, Cart}
  alias LocalCafe.Menu.MenuItem

  def add(conn, %{"cart" => cart_params}) do
    menu_item_id = cart_params["menu_item_id"]
    price_index = String.to_integer(cart_params["price_index"] || "0")
    customer_note = cart_params["customer_note"]

    variant_indices =
      case cart_params["variant_indices"] do
        nil -> []
        indices when is_list(indices) -> Enum.map(indices, &String.to_integer/1)
        _ -> []
      end

    case Repo.get(MenuItem, menu_item_id) do
      nil ->
        conn
        |> put_flash(:error, "Menu item not found")
        |> redirect(to: ~p"/menu")

      menu_item ->
        conn = Cart.add_to_cart(conn, menu_item, price_index, variant_indices, customer_note)

        conn
        |> put_flash(:info, "#{menu_item.title} added to cart")
        |> redirect(to: ~p"/menu/#{menu_item.slug}")
    end
  end

  def index(conn, _params) do
    cart = Cart.get_cart(conn)
    subtotal = Cart.cart_subtotal(cart)

    render(conn, :index,
      cart: cart,
      subtotal: subtotal,
      page_title: "Your Cart"
    )
  end

  def update_quantity(conn, %{"index" => index, "quantity" => quantity}) do
    item_index = String.to_integer(index)
    quantity = String.to_integer(quantity)

    conn = Cart.update_quantity(conn, item_index, quantity)

    conn
    |> put_flash(:info, "Cart updated")
    |> redirect(to: ~p"/cart")
  end

  def remove(conn, %{"index" => index}) do
    item_index = String.to_integer(index)
    conn = Cart.remove_from_cart(conn, item_index)

    conn
    |> put_flash(:info, "Item removed from cart")
    |> redirect(to: ~p"/cart")
  end

  def clear(conn, _params) do
    conn = Cart.clear_cart(conn)

    conn
    |> put_flash(:info, "Cart cleared")
    |> redirect(to: ~p"/#menu")
  end
end
