defmodule LocalCafe.Repo.Migrations.CreateHeroSlides do
  use Ecto.Migration

  def change do
    create table(:hero_slides) do
      add :tagline, :text, null: false
      add :image, :map
      add :position, :integer, default: 0, null: false
      add :active, :boolean, default: true, null: false
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:hero_slides, [:user_id])
    create index(:hero_slides, [:active])
    create index(:hero_slides, [:position])
  end
end
