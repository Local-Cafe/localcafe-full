defmodule LocalCafe.Repo.Migrations.AddPostSearch do
  use Ecto.Migration

  def up do
    # Enable pg_trgm extension for fuzzy/similarity search
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"

    # Add GIN index for trigram similarity search on title, description, and body
    # This enables fuzzy matching and typo tolerance
    execute """
    CREATE INDEX posts_trigram_index ON posts
    USING gin(
      (title || ' ' || coalesce(description, '') || ' ' || coalesce(body, '')) gin_trgm_ops
    )
    """
  end

  def down do
    execute "DROP INDEX IF EXISTS posts_trigram_index"
    execute "DROP EXTENSION IF EXISTS pg_trgm"
  end
end
