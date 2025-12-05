defmodule LocalCafe.Repo.Migrations.CreatePosts do
  use Ecto.Migration

  def change do
    create table(:posts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string
      add :slug, :string
      add :description, :text
      add :body, :text
      add :published_at, :date
      add :images, :jsonb, default: "[]"
      add :draft, :boolean, default: false, null: false
      add :price, :integer, null: true, comment: "Price in cents; null means free post"
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:posts, [:user_id])
    create index(:posts, [:images], using: :gin)

    execute """
    -- Create a new partial index excluding flagged posts
    CREATE INDEX posts_fulltext_index ON posts
    USING gin(
        to_tsvector(
          'english',
          coalesce(title, '') || ' ' ||
          coalesce(description, '') || ' ' ||
          coalesce(body, '')
        )
      )
    """
  end
end
