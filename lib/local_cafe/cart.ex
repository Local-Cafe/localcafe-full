defmodule LocalCafe.Cart do
  @moduledoc """
  Shopping cart functionality.

  Manages cart items stored in the session for both guests and authenticated users.
  """

  alias LocalCafe.Cart.CartItem

  @doc """
  Gets the current cart from the session.

  Returns a list of CartItem structs.
  """
  def get_cart(conn) do
    conn
    |> Plug.Conn.get_session(:cart)
    |> case do
      nil -> []
      items when is_list(items) -> Enum.map(items, &struct(CartItem, &1))
    end
  end

  @doc """
  Adds an item to the cart.

  If the item already exists (same menu_item_id, price, variants, and note),
  increments the quantity. Otherwise adds a new cart item.
  """
  def add_to_cart(conn, menu_item, price_index, variant_indices, customer_note \\ nil) do
    cart = get_cart(conn)

    selected_price = Enum.at(menu_item.prices, price_index)

    selected_variants =
      variant_indices
      |> Enum.map(fn idx -> Enum.at(menu_item.variants, idx) end)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(fn variant ->
        %{name: variant.name, price: variant.price}
      end)

    # Check if item already exists in cart (same item, price, variants, and note)
    existing_item_index =
      Enum.find_index(cart, fn item ->
        item.menu_item_id == menu_item.id &&
          item.price_index == price_index &&
          item.variant_indices == variant_indices &&
          item.customer_note == customer_note
      end)

    cart =
      if existing_item_index do
        # Increment quantity of existing item
        List.update_at(cart, existing_item_index, fn item ->
          %{item | quantity: item.quantity + 1}
        end)
      else
        # Add new item
        # Get primary image or first image
        item_image_url =
          cond do
            menu_item.images && length(menu_item.images) > 0 ->
              primary_image = Enum.find(menu_item.images, fn img -> img.is_primary end)
              first_image = List.first(menu_item.images)
              image = primary_image || first_image
              image.thumb_url

            true ->
              nil
          end

        new_item = %CartItem{
          menu_item_id: menu_item.id,
          item_title: menu_item.title,
          item_description: menu_item.description,
          item_image_url: item_image_url,
          price_index: price_index,
          base_price_label: selected_price.label,
          base_price_amount: selected_price.amount,
          variant_indices: variant_indices,
          selected_variants: selected_variants,
          customer_note: customer_note,
          quantity: 1
        }

        cart ++ [new_item]
      end

    Plug.Conn.put_session(conn, :cart, Enum.map(cart, &Map.from_struct/1))
  end

  @doc """
  Updates the quantity of a cart item.
  """
  def update_quantity(conn, item_index, quantity) when quantity > 0 do
    cart = get_cart(conn)

    cart =
      if item_index < length(cart) do
        List.update_at(cart, item_index, fn item ->
          %{item | quantity: quantity}
        end)
      else
        cart
      end

    Plug.Conn.put_session(conn, :cart, Enum.map(cart, &Map.from_struct/1))
  end

  def update_quantity(conn, item_index, _quantity) do
    # If quantity is 0 or less, remove the item
    remove_from_cart(conn, item_index)
  end

  @doc """
  Removes an item from the cart by index.
  """
  def remove_from_cart(conn, item_index) do
    cart = get_cart(conn)
    cart = List.delete_at(cart, item_index)
    Plug.Conn.put_session(conn, :cart, Enum.map(cart, &Map.from_struct/1))
  end

  @doc """
  Clears the entire cart.
  """
  def clear_cart(conn) do
    Plug.Conn.put_session(conn, :cart, [])
  end

  @doc """
  Gets the total number of items in the cart.
  """
  def cart_count(conn) do
    conn
    |> get_cart()
    |> Enum.reduce(0, fn item, acc -> acc + item.quantity end)
  end

  @doc """
  Calculates the cart subtotal in cents.
  """
  def cart_subtotal(cart) when is_list(cart) do
    Enum.reduce(cart, 0, fn item, acc ->
      item_total = item.base_price_amount
      variant_total = Enum.reduce(item.selected_variants, 0, fn v, acc -> acc + v.price end)
      acc + (item_total + variant_total) * item.quantity
    end)
  end

  @doc """
  Converts the cart to order attributes ready for Orders.create_order/2.
  """
  def cart_to_order_attrs(cart, customer_note \\ nil, customer_name \\ nil, customer_email \\ nil) do
    line_items =
      cart
      |> Enum.with_index()
      |> Enum.map(fn {item, position} ->
        %{
          menu_item_id: item.menu_item_id,
          item_title: item.item_title,
          item_description: item.item_description,
          base_price_label: item.base_price_label,
          base_price_amount: item.base_price_amount,
          selected_variants: item.selected_variants,
          customer_note: item.customer_note,
          quantity: item.quantity,
          position: position
        }
      end)

    %{
      customer_note: customer_note,
      customer_name: customer_name,
      customer_email: customer_email,
      line_items: line_items
    }
  end
end
