defmodule LocalCafe.Posts.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  alias LocalCafe.Posts.Post
  alias LocalCafe.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "comments" do
    field :body, :string
    field :approved, :boolean, default: false

    belongs_to :post, Post
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :approved, :post_id, :user_id])
    |> trim_body()
    |> validate_required([:body, :post_id, :user_id])
    |> validate_length(:body, min: 3, max: 5000)
    |> foreign_key_constraint(:post_id)
    |> foreign_key_constraint(:user_id)
  end

  defp trim_body(changeset) do
    case get_change(changeset, :body) do
      nil -> changeset
      body when is_binary(body) -> put_change(changeset, :body, String.trim(body))
      _ -> changeset
    end
  end
end
