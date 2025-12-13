defmodule LocalCafe.Menu.MenuItemVariant do
  @moduledoc """
  Embedded schema for menu item variants/options.

  Variants are optional add-ons or modifications to menu items.
  Examples: "Extra Cheese" => 200 (cents), "No Onion" => 0

  Price can be 0 for no-cost options (which won't show a price in the UI).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:name, :price, :position]}
  @primary_key false
  embedded_schema do
    field :name, :string
    field :price, :integer
    field :position, :integer
  end

  @doc false
  def changeset(variant, attrs) do
    variant
    |> cast(attrs, [:name, :price, :position])
    |> validate_required([:name, :price, :position])
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> validate_length(:name, min: 1, max: 100)
  end
end
