defmodule LocalCafeWeb.Plugs.AssignCartCount do
  @moduledoc """
  Plug to assign cart information to conn for use in layouts and templates.
  """
  import Plug.Conn
  alias LocalCafe.Cart

  def init(opts), do: opts

  def call(conn, _opts) do
    cart = Cart.get_cart(conn)
    cart_count = Enum.reduce(cart, 0, fn item, acc -> acc + item.quantity end)
    cart_subtotal = Cart.cart_subtotal(cart)

    conn
    |> assign(:cart_count, cart_count)
    |> assign(:cart_subtotal, cart_subtotal)
  end
end
