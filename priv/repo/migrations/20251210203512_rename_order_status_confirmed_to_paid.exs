defmodule LocalCafe.Repo.Migrations.RenameOrderStatusConfirmedToPaid do
  use Ecto.Migration

  def up do
    # Update any existing orders with status "confirmed" to "paid"
    execute "UPDATE orders SET status = 'paid' WHERE status = 'confirmed'"
  end

  def down do
    # Revert back to "confirmed" if rolling back
    execute "UPDATE orders SET status = 'confirmed' WHERE status = 'paid'"
  end
end
