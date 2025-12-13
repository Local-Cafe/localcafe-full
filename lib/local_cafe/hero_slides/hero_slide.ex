defmodule LocalCafe.HeroSlides.HeroSlide do
  use Ecto.Schema
  import Ecto.Changeset

  alias LocalCafe.Accounts.User

  @primary_key {:id, :id, autogenerate: true}
  schema "hero_slides" do
    field :tagline, :string
    field :position, :integer, default: 0
    field :active, :boolean, default: true

    # Image stored as JSONB with same structure as menu items
    embeds_one :image, Image, primary_key: false, on_replace: :delete do
      field :full_url, :string
      field :thumb_url, :string
      field :filename, :string
    end

    belongs_to :user, User, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(hero_slide, attrs) do
    hero_slide
    |> cast(attrs, [:tagline, :position, :active, :user_id])
    |> validate_required([:tagline, :user_id])
    |> cast_embed(:image, with: &image_changeset/2)
    |> foreign_key_constraint(:user_id)
  end

  defp image_changeset(image, attrs) do
    image
    |> cast(attrs, [:full_url, :thumb_url, :filename])
  end
end
