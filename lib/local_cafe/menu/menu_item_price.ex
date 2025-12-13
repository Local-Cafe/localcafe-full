defmodule LocalCafe.Menu.MenuItemPrice do
  @moduledoc """
  Embedded schema for menu item prices.

  Each menu item must have at least one price. Prices are stored in cents.
  - For single price items: label is nil
  - For multiple price items: label describes the variant (e.g., "Small", "Large")
  """
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:label, :amount, :position]}
  @primary_key false
  embedded_schema do
    field :label, :string
    field :amount, :integer
    field :position, :integer
  end

  @doc false
  def changeset(price, attrs) do
    price
    |> cast(attrs, [:label, :amount, :position])
    |> validate_required([:amount, :position])
    |> validate_number(:amount, greater_than_or_equal_to: 0)
    |> validate_number(:position, greater_than_or_equal_to: 0)
  end
end
