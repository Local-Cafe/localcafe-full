defmodule LocalCafe.Repo.Migrations.CreateMenuItemLocations do
  use Ecto.Migration

  def change do
    create table(:menu_item_locations, primary_key: false) do
      add :menu_item_id, references(:menu_items, type: :binary_id, on_delete: :delete_all), null: false
      add :location_id, references(:locations, on_delete: :delete_all), null: false
    end

    create index(:menu_item_locations, [:menu_item_id])
    create index(:menu_item_locations, [:location_id])
    create unique_index(:menu_item_locations, [:menu_item_id, :location_id])
  end
end
