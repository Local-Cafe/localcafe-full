defmodule LocalCafe.Menu.MenuItemImage do
  @moduledoc """
  Embedded schema for menu item images.

  Each menu item can have multiple images with full and thumbnail versions.
  Images can be reordered (via position) and one can be marked as primary.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:full_url, :thumb_url, :position, :is_primary]}
  @primary_key false
  embedded_schema do
    field :full_url, :string
    field :thumb_url, :string
    field :position, :integer
    field :is_primary, :boolean, default: false
  end

  @doc false
  def changeset(menu_item_image, attrs) do
    menu_item_image
    |> cast(attrs, [:full_url, :thumb_url, :position, :is_primary])
    |> validate_required([:full_url, :thumb_url, :position])
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> validate_url(:full_url)
    |> validate_url(:thumb_url)
  end

  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn _, value ->
      uri = URI.parse(value)

      if uri.scheme in ["http", "https"] and uri.host do
        []
      else
        [{field, "must be a valid HTTP or HTTPS URL"}]
      end
    end)
  end
end
