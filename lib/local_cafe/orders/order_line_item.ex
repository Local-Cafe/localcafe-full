defmodule LocalCafe.Orders.OrderLineItem do
  @moduledoc """
  Schema for order line items.

  Each line item represents one menu item in an order, with:
  - Snapshot of the item details (title, description)
  - Selected price (label and amount)
  - Selected variants with their prices
  - Calculated subtotal
  - Optional customer note
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias LocalCafe.Orders.Order
  alias LocalCafe.Menu.MenuItem
  alias LocalCafe.Orders.SelectedVariant

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "order_line_items" do
    field :item_title, :string
    field :item_description, :string
    field :base_price_label, :string
    field :base_price_amount, :integer
    field :subtotal, :integer
    field :customer_note, :string
    field :position, :integer, default: 0
    field :quantity, :integer, default: 1

    embeds_many :selected_variants, SelectedVariant, on_replace: :delete

    belongs_to :order, Order
    belongs_to :menu_item, MenuItem

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(line_item, attrs) do
    line_item
    |> cast(attrs, [
      :menu_item_id,
      :item_title,
      :item_description,
      :base_price_label,
      :base_price_amount,
      :customer_note,
      :position,
      :quantity
    ])
    |> validate_required([:menu_item_id, :item_title, :base_price_amount])
    |> validate_number(:quantity, greater_than: 0)
    |> cast_embed(:selected_variants, with: &SelectedVariant.changeset/2)
    |> calculate_subtotal()
  end

  defp calculate_subtotal(changeset) do
    base_price = get_field(changeset, :base_price_amount) || 0
    variants = get_field(changeset, :selected_variants) || []
    quantity = get_field(changeset, :quantity) || 1

    variant_total =
      Enum.reduce(variants, 0, fn variant, acc ->
        acc + (variant.price || 0)
      end)

    put_change(changeset, :subtotal, (base_price + variant_total) * quantity)
  end
end
