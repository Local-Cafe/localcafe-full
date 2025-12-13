defmodule LocalCafe.Repo.Migrations.CreateLocations do
  use Ecto.Migration

  def change do
    create table(:locations) do
      add :name, :string, null: false
      add :description, :text
      add :street, :string
      add :city_state, :string
      add :phone, :string
      add :email, :string
      add :hours, :jsonb, default: "[]"
      add :image, :jsonb
      add :slug, :string, null: false
      add :active, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:locations, [:slug])
    create index(:locations, [:active])
  end
end
