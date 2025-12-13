defmodule LocalCafe.Posts.PostPurchase do
  use Ecto.Schema
  import Ecto.Changeset

  alias LocalCafe.Posts.Post
  alias LocalCafe.Accounts.User
  alias LocalCafe.Billing.Payment

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "post_purchases" do
    field :amount, :integer

    belongs_to :user, User
    belongs_to :post, Post
    belongs_to :payment, Payment

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(post_purchase, attrs) do
    post_purchase
    |> cast(attrs, [:user_id, :post_id, :payment_id, :amount])
    |> validate_required([:user_id, :post_id, :amount])
    |> validate_number(:amount, greater_than: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:post_id)
    |> foreign_key_constraint(:payment_id)
    |> unique_constraint([:user_id, :post_id], name: :post_purchases_user_id_post_id_index)
  end
end
