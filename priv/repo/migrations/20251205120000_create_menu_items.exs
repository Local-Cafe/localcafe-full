defmodule LocalCafe.Repo.Migrations.CreateMenuItems do
  use Ecto.Migration

  def change do
    create table(:menu_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :slug, :string, null: false
      add :description, :text, null: false
      add :special, :boolean, default: false, null: false

      add :images, :jsonb,
        default: "[]",
        null: false,
        comment: "Array of image objects with full_url, thumb_url, position, is_primary"

      add :prices, :jsonb,
        default: "[]",
        null: false,
        comment: "Array of price objects: {label, amount, position}. Single price has label: nil"

      add :variants, :jsonb,
        default: "[]",
        null: false,
        comment: "Array of variant objects: {name, price, position}. Price can be 0"

      add :available, :boolean, default: true, null: false
      add :position, :integer, default: 0, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:menu_items, [:user_id])
    create index(:menu_items, [:available])
    create index(:menu_items, [:position])
    create unique_index(:menu_items, [:slug])
    create index(:menu_items, [:images], using: :gin)
    create index(:menu_items, [:prices], using: :gin)
    create index(:menu_items, [:variants], using: :gin)
    create index(:menu_items, [:special])

    # Full-text search on menu items
    execute """
    CREATE INDEX menu_items_fulltext_index ON menu_items
    USING gin(
      to_tsvector(
        'english',
        coalesce(title, '') || ' ' ||
        coalesce(description, '')
      )
    )
    """

    # Trigram search for fuzzy matching
    execute """
            CREATE INDEX menu_items_trigram_index ON menu_items
            USING gin(
              (title || ' ' || coalesce(description, '')) gin_trgm_ops
            )
            """,
            ""
  end
end
