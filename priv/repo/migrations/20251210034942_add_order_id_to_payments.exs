defmodule LocalCafe.Repo.Migrations.AddOrderIdToPayments do
  use Ecto.Migration

  def change do
    alter table(:payments) do
      add :order_id, references(:orders, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:payments, [:order_id])
  end
end
