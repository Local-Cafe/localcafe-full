defmodule LocalCafe.Posts.Post do
  use Ecto.Schema
  import Ecto.Changeset

  alias LocalCafe.Tags.Tag
  alias LocalCafe.Posts.Comment
  alias LocalCafe.Posts.PostImage
  alias LocalCafe.Repo

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Phoenix.Param, key: :slug}
  schema "posts" do
    field :title, :string
    field :slug, :string
    field :description, :string
    field :body, :string
    field :published_at, :date
    field :draft, :boolean, default: false
    field :price, :integer
    field :user_id, :binary_id

    embeds_many :images, PostImage, on_replace: :delete

    many_to_many :tags, Tag, join_through: "post_tags", on_replace: :delete
    has_many :comments, Comment

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(post, attrs, user_scope) do
    post
    |> Repo.preload(:tags)
    |> cast(attrs, [:title, :slug, :description, :body, :published_at, :draft, :price])
    |> validate_required([:title, :slug, :description, :body, :published_at])
    |> validate_length(:title, min: 3, max: 255)
    |> validate_length(:slug, min: 3, max: 255)
    |> validate_format(:slug, ~r/^[a-z0-9-]+$/,
      message: "must be lowercase letters, numbers, and hyphens only"
    )
    |> validate_length(:description, min: 10, max: 500)
    |> validate_length(:body, min: 10)
    |> validate_number(:price, greater_than_or_equal_to: 0)
    |> unique_constraint(:slug)
    |> put_change(:user_id, user_scope.user.id)
    |> cast_embed(:images, with: &PostImage.changeset/2)
    |> validate_at_most_one_primary()
    |> put_tags(attrs)
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
end
