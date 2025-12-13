defmodule LocalCafe.Repo.Migrations.AddTipAmountToPayments do
  use Ecto.Migration

  def change do
    alter table(:payments) do
      add :tip_amount, :integer, default: 0, comment: "Tip/gratuity amount in cents"
    end
  end
end
