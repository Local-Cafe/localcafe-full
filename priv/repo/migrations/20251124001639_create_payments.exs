defmodule LocalCafe.Repo.Migrations.CreatePayments do
  use Ecto.Migration

  def change do
    create table(:payments, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # Stripe identifiers
      add :stripe_payment_intent_id, :string, null: false
      add :stripe_charge_id, :string
      add :stripe_customer_id, :string

      # Payment details
      add :amount, :integer, null: false
      add :currency, :string, null: false, default: "usd"
      add :status, :string, null: false
      add :payment_method, :string
      add :customer_email, :string
      add :description, :text

      # Additional metadata
      add :metadata, :map, default: "{}"
      add :stripe_metadata, :map, default: "{}"

      # Failed payment info
      add :failure_code, :string
      add :failure_message, :text

      # Associations
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      # Amount fields
      add :amount_received, :integer, comment: "Actual amount collected (may differ from amount)"
      add :amount_refunded, :integer, default: 0, comment: "Total amount refunded"

      # Fee information (from BalanceTransaction)
      add :fee, :integer, comment: "Total Stripe fees in cents"
      add :net, :integer, comment: "Net amount after fees (amount - fee)"
      add :fee_details, :map, comment: "Detailed breakdown of fees"
      add :balance_transaction_id, :string, comment: "Stripe balance transaction ID"

      # Application fees
      add :application_fee_amount, :integer,
        comment: "Application fee amount if using Stripe Connect"

      # Receipt information
      add :receipt_email, :string, comment: "Email where receipt was sent"
      add :receipt_number, :string, comment: "Receipt number shown on email receipts"
      add :receipt_url, :string, comment: "URL to view receipt"

      # Event history - stores all payment state changes as events
      add :events, :jsonb,
        default: "[]",
        null: false,
        comment: "Event history for this payment - ordered list of state changes"

      # Payment method details
      add :payment_method_type, :string,
        comment: "Type of payment method (card, bank_account, etc)"

      add :card_brand, :string, comment: "Card brand (visa, mastercard, amex, etc)"
      add :card_last4, :string, comment: "Last 4 digits of card"
      add :card_exp_month, :integer, comment: "Card expiration month"
      add :card_exp_year, :integer, comment: "Card expiration year"
      add :card_fingerprint, :string, comment: "Unique card identifier"

      # Financial timeline
      add :available_on, :date, comment: "Date when funds become available in Stripe balance"

      add :exchange_rate, :decimal,
        precision: 20,
        scale: 12,
        comment: "Exchange rate if currency conversion"

      # Additional tracking
      add :livemode, :boolean,
        default: true,
        comment: "Whether payment was in live mode or test mode"

      timestamps(type: :utc_datetime)
    end

    create index(:payments, [:user_id])
    create index(:payments, [:status])
    create index(:payments, [:customer_email])
    create index(:payments, [:stripe_customer_id])
    create index(:payments, [:balance_transaction_id])
    create index(:payments, [:receipt_number])
    create index(:payments, [:card_fingerprint])
    create index(:payments, [:livemode])
    create unique_index(:payments, [:stripe_payment_intent_id])

    # GIN index on events for querying event history
    create index(:payments, [:events], using: :gin)
  end
end
