defmodule LocalCafe.Repo.Migrations.AddQuantityToOrderLineItems do
  use Ecto.Migration

  def change do
    alter table(:order_line_items) do
      add :quantity, :integer, default: 1, null: false
    end
  end
end
