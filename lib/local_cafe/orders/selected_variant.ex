defmodule LocalCafe.Orders.SelectedVariant do
  @moduledoc """
  Embedded schema for selected variants in an order line item.

  This is a snapshot of the variant at the time of order.
  Stores the variant name and price to preserve historical pricing.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:name, :price]}
  @primary_key false
  embedded_schema do
    field :name, :string
    field :price, :integer
  end

  @doc false
  def changeset(variant, attrs) do
    variant
    |> cast(attrs, [:name, :price])
    |> validate_required([:name, :price])
  end
end
