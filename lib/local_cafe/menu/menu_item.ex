defmodule LocalCafe.Menu.MenuItem do
  use Ecto.Schema
  import Ecto.Changeset

  alias LocalCafe.Tags.Tag
  alias LocalCafe.Menu.MenuItemImage
  alias LocalCafe.Menu.MenuItemPrice
  alias LocalCafe.Menu.MenuItemVariant
  alias LocalCafe.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Phoenix.Param, key: :slug}
  schema "menu_items" do
    field :title, :string
    field :slug, :string
    field :description, :string
    field :available, :boolean, default: true
    field :special, :boolean, default: false
    field :position, :integer, default: 0
    field :user_id, :binary_id

    embeds_many :images, MenuItemImage, on_replace: :delete
    embeds_many :prices, MenuItemPrice, on_replace: :delete
    embeds_many :variants, MenuItemVariant, on_replace: :delete

    many_to_many :tags, Tag, join_through: "menu_item_tags", on_replace: :delete
    many_to_many :locations, LocalCafe.Locations.Location,
      join_through: "menu_item_locations",
      on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(menu_item, attrs, user_scope) do
    menu_item
    |> Repo.preload([:tags, :locations])
    |> cast(attrs, [:title, :slug, :description, :available, :special, :position])
    |> validate_required([:title, :slug, :description])
    |> validate_length(:title, min: 3, max: 255)
    |> validate_length(:slug, min: 3, max: 255)
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/,
      message: "must be lowercase letters, numbers, and hyphens only"
    )
    |> validate_length(:description, min: 10, max: 500)
    |> unique_constraint(:slug)
    |> put_change(:user_id, user_scope.user.id)
    |> cast_embed(:images, with: &MenuItemImage.changeset/2)
    |> cast_embed(:prices, with: &MenuItemPrice.changeset/2)
    |> cast_embed(:variants, with: &MenuItemVariant.changeset/2)
    |> validate_at_least_one_price()
    |> validate_at_most_one_primary()
    |> put_tags(attrs)
    |> put_locations(attrs)
  end

  defp validate_at_least_one_price(changeset) do
    case get_change(changeset, :prices) do
      nil ->
        # Check existing prices on struct
        if get_field(changeset, :prices) == [] or is_nil(get_field(changeset, :prices)) do
          add_error(changeset, :prices, "must have at least one price")
        else
          changeset
        end

      prices ->
        if Enum.empty?(prices) do
          add_error(changeset, :prices, "must have at least one price")
        else
          changeset
        end
    end
  end

  defp validate_at_most_one_primary(changeset) do
    case get_change(changeset, :images) do
      nil ->
        changeset

      images ->
        # Only count images that will be in the final result (action: :insert or :update)
        # Ignore images with action: :replace since they'll be deleted due to on_replace: :delete
        primary_count =
          images
          |> Enum.reject(&(&1.action == :replace))
          |> Enum.count(fn img -> get_field(img, :is_primary) end)

        if primary_count > 1 do
          add_error(changeset, :images, "only one image can be marked as primary")
        else
          changeset
        end
    end
  end

  defp put_tags(changeset, %{"tags" => tags_string}) when is_binary(tags_string) do
    tag_names =
      tags_string
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&String.downcase/1)
      |> Enum.uniq()

    tags =
      Enum.map(tag_names, fn name ->
        Repo.get_by(Tag, name: name) ||
          Repo.insert!(%Tag{name: name})
      end)

    put_assoc(changeset, :tags, tags)
  end

  defp put_tags(changeset, _attrs), do: changeset

  defp put_locations(changeset, %{"location_ids" => location_ids}) when is_list(location_ids) do
    locations =
      location_ids
      |> Enum.reject(&(&1 == "" || is_nil(&1)))
      |> Enum.map(&String.to_integer/1)
      |> Enum.map(&Repo.get!(LocalCafe.Locations.Location, &1))

    put_assoc(changeset, :locations, locations)
  end

  defp put_locations(changeset, _attrs), do: changeset
end
