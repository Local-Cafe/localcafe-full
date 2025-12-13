defmodule LocalCafe.Repo.Migrations.AddStatusEventsToOrders do
  use Ecto.Migration

  def change do
    alter table(:orders) do
      add :status_events, :jsonb, default: "[]", null: false
    end

    # Add an index on status_events for better query performance
    create index(:orders, [:status_events], using: :gin)
  end
end
