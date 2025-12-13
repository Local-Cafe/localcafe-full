defmodule LocalCafe.Repo.Migrations.CreateOrders do
  use Ecto.Migration

  def change do
    create table(:orders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :order_number, :string, null: false, comment: "Format: ORD-YYYYMMDD-NNNN"

      add :status, :string,
        null: false,
        default: "pending",
        comment: "pending, confirmed, preparing, ready, completed, cancelled"

      add :subtotal, :integer,
        null: false,
        comment: "Total amount in cents (sum of all line items)"

      add :customer_note, :text
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :customer_name, :string
      add :customer_email, :string
      add :completed_at, :utc_datetime
      add :cancelled_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:orders, [:user_id])
    create index(:orders, [:status])
    create index(:orders, [:customer_email])
    create unique_index(:orders, [:order_number])
    create index(:orders, [:inserted_at])

    create table(:order_line_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :order_id, references(:orders, type: :binary_id, on_delete: :delete_all), null: false

      add :menu_item_id, references(:menu_items, type: :binary_id, on_delete: :restrict),
        null: false,
        comment: "restrict prevents deleting menu items with order history"

      # Snapshot of item at time of order
      add :item_title, :string, null: false
      add :item_description, :text

      # Selected price snapshot
      add :base_price_label, :string,
        comment: "nil for single-price items, 'Small'/'Large' for multi-price"

      add :base_price_amount, :integer, null: false, comment: "Price in cents"

      # Selected variants snapshot
      add :selected_variants, :jsonb,
        default: "[]",
        null: false,
        comment: "Array of {name, price} for selected variants"

      add :subtotal, :integer,
        null: false,
        comment: "base_price_amount + sum(selected_variants.price)"

      add :customer_note, :text, comment: "Line-item specific note"
      add :position, :integer, default: 0, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:order_line_items, [:order_id])
    create index(:order_line_items, [:menu_item_id])
    create index(:order_line_items, [:selected_variants], using: :gin)
  end
end
