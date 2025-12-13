defmodule LocalCafe.Cart.CartItem do
  @moduledoc """
  Represents an item in the shopping cart.

  This is a plain struct (not an Ecto schema) that gets stored in the session.
  """

  @derive Jason.Encoder
  defstruct [
    :menu_item_id,
    :item_title,
    :item_description,
    :item_image_url,
    :price_index,
    :base_price_label,
    :base_price_amount,
    :variant_indices,
    :selected_variants,
    :customer_note,
    quantity: 1
  ]

  @type t :: %__MODULE__{
          menu_item_id: String.t(),
          item_title: String.t(),
          item_description: String.t(),
          item_image_url: String.t() | nil,
          price_index: integer(),
          base_price_label: String.t() | nil,
          base_price_amount: integer(),
          variant_indices: list(integer()),
          selected_variants: list(map()),
          customer_note: String.t() | nil,
          quantity: integer()
        }
end
