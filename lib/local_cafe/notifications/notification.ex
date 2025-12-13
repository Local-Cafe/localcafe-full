defmodule LocalCafe.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field :title, :string
    field :body, :string
    field :redirect_link, :string
    field :viewed_at, :utc_datetime

    belongs_to :user, LocalCafe.Accounts.User, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:user_id, :title, :body, :redirect_link, :viewed_at])
    |> validate_required([:user_id, :title, :body, :redirect_link])
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Marks a notification as viewed with the current timestamp.
  """
  def mark_as_viewed_changeset(notification) do
    change(notification, viewed_at: DateTime.utc_now() |> DateTime.truncate(:second))
  end
end
