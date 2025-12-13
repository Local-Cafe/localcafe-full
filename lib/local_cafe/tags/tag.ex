defmodule LocalCafe.Tags.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  alias LocalCafe.Posts.Post
  alias LocalCafe.Menu.MenuItem

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tags" do
    field :name, :string

    many_to_many :posts, Post, join_through: "post_tags"
    many_to_many :menu_items, MenuItem, join_through: "menu_item_tags"

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 50)
    |> validate_format(:name, ~r/^[a-z0-9-]+$/,
      message: "must be lowercase letters, numbers, and hyphens only"
    )
    |> unique_constraint(:name)
  end
end
