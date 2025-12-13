defmodule LocalCafe.Repo.Migrations.AddTagsToPosts do
  use Ecto.Migration

  def change do
    create table(:tags, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tags, [:name])

    create table(:post_tags, primary_key: false) do
      add :post_id, references(:posts, type: :binary_id, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, type: :binary_id, on_delete: :delete_all), null: false
    end

    create index(:post_tags, [:post_id])
    create index(:post_tags, [:tag_id])
    create unique_index(:post_tags, [:post_id, :tag_id])
  end
end
