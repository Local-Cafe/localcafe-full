defmodule LocalCafe.Locations.Location do
  use Ecto.Schema
  import Ecto.Changeset

  schema "locations" do
    field :name, :string
    field :description, :string
    field :street, :string
    field :city_state, :string
    field :phone, :string
    field :email, :string
    field :hours, {:array, :string}, default: []
    field :image, :map
    field :slug, :string
    field :active, :boolean, default: true

    many_to_many :menu_items, LocalCafe.Menu.MenuItem,
      join_through: "menu_item_locations",
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(location, attrs) do
    location
    |> cast(attrs, [:name, :description, :street, :city_state, :phone, :email, :hours, :image, :slug, :active])
    |> validate_required([:name, :slug])
    |> validate_format(:email, ~r/@/, message: "must be a valid email")
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/, message: "must be lowercase alphanumeric with dashes")
    |> unique_constraint(:slug)
    |> maybe_generate_slug()
  end

  defp maybe_generate_slug(changeset) do
    if get_field(changeset, :slug) do
      changeset
    else
      case get_change(changeset, :name) do
        nil -> changeset
        name -> put_change(changeset, :slug, slugify(name))
      end
    end
  end

  defp slugify(str) do
    str
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "-")
  end
end
