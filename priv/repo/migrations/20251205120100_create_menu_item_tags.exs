defmodule LocalCafe.Repo.Migrations.CreateMenuItemTags do
  use Ecto.Migration

  def change do
    create table(:menu_item_tags, primary_key: false) do
      add :menu_item_id, references(:menu_items, type: :binary_id, on_delete: :delete_all),
        null: false

      add :tag_id, references(:tags, type: :binary_id, on_delete: :delete_all), null: false
    end

    create index(:menu_item_tags, [:menu_item_id])
    create index(:menu_item_tags, [:tag_id])
    create unique_index(:menu_item_tags, [:menu_item_id, :tag_id])
  end
end
