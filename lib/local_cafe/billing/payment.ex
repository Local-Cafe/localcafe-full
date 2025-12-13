defmodule LocalCafe.Billing.Payment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  # Valid payment statuses from Stripe
  @valid_statuses ~w(requires_payment_method requires_confirmation requires_action processing succeeded canceled)

  schema "payments" do
    # Stripe identifiers
    field :stripe_payment_intent_id, :string
    field :stripe_charge_id, :string
    field :stripe_customer_id, :string
    field :balance_transaction_id, :string

    # Payment amounts
    field :amount, :integer
    field :amount_received, :integer
    field :amount_refunded, :integer
    field :tip_amount, :integer, default: 0
    field :currency, :string, default: "usd"

    # Fee information (from BalanceTransaction)
    field :fee, :integer
    field :net, :integer
    field :fee_details, {:array, :map}
    field :application_fee_amount, :integer

    # Payment status (derived from events)
    field :status, :string

    # Event history - stores all payment state changes
    field :events, {:array, :map}, default: []

    # Payment method details
    field :payment_method, :string
    field :payment_method_type, :string
    field :card_brand, :string
    field :card_last4, :string
    field :card_exp_month, :integer
    field :card_exp_year, :integer
    field :card_fingerprint, :string

    # Customer & receipt information
    field :customer_email, :string
    field :receipt_email, :string
    field :receipt_number, :string
    field :receipt_url, :string
    field :description, :string

    # Financial timeline
    field :available_on, :date
    field :exchange_rate, :decimal

    # Metadata
    field :metadata, :map, default: %{}
    field :stripe_metadata, :map, default: %{}
    field :livemode, :boolean

    # Failed payment info
    field :failure_code, :string
    field :failure_message, :string

    # Associations
    belongs_to :user, LocalCafe.Accounts.User
    belongs_to :order, LocalCafe.Orders.Order

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(payment, attrs) do
    payment
    |> cast(attrs, [
      # Stripe IDs
      :stripe_payment_intent_id,
      :stripe_charge_id,
      :stripe_customer_id,
      :balance_transaction_id,
      # Amounts
      :amount,
      :amount_received,
      :amount_refunded,
      :tip_amount,
      :currency,
      # Fees
      :fee,
      :net,
      :fee_details,
      :application_fee_amount,
      # Status (derived from events, but can be set directly for backwards compat)
      :status,
      # Events
      :events,
      # Payment method
      :payment_method,
      :payment_method_type,
      :card_brand,
      :card_last4,
      :card_exp_month,
      :card_exp_year,
      :card_fingerprint,
      # Customer & receipt
      :customer_email,
      :receipt_email,
      :receipt_number,
      :receipt_url,
      :description,
      # Timeline
      :available_on,
      :exchange_rate,
      # Metadata
      :metadata,
      :stripe_metadata,
      :livemode,
      # Failures
      :failure_code,
      :failure_message,
      # Associations
      :user_id,
      :order_id
    ])
    |> validate_required([:stripe_payment_intent_id, :amount, :currency, :status])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_number(:amount, greater_than: 0)
    |> validate_format(:customer_email, ~r/@/, message: "must be a valid email")
    |> unique_constraint(:stripe_payment_intent_id)
  end

  @doc """
  Changeset for creating a payment from a Stripe PaymentIntent
  Extracts comprehensive payment data including fees, card details, and receipts
  """
  def from_stripe_changeset(payment, stripe_payment_intent, attrs \\ %{}) do
    # Get the charge object from latest_charge or charges list
    charge =
      cond do
        # Check if latest_charge is expanded (struct)
        is_struct(stripe_payment_intent.latest_charge) ->
          stripe_payment_intent.latest_charge

        # Check if latest_charge is a string ID
        is_binary(stripe_payment_intent.latest_charge) ->
          nil

        # Fallback to charges list if available (from webhook events)
        is_map(Map.get(stripe_payment_intent, :charges)) ->
          stripe_payment_intent.charges
          |> Map.get(:data, [])
          |> List.first()

        true ->
          nil
      end

    # Get payment method details (using struct field access)
    payment_method = charge && Map.get(charge, :payment_method_details)
    card_details = payment_method && Map.get(payment_method, :card)

    # Get balance transaction (if expanded as struct)
    balance_transaction =
      charge && Map.get(charge, :balance_transaction)

    # Build base attributes from PaymentIntent
    base_attrs = %{
      # Stripe IDs
      stripe_payment_intent_id: stripe_payment_intent.id,
      stripe_customer_id: stripe_payment_intent.customer,
      stripe_charge_id: charge && Map.get(charge, :id),
      # Amounts from PaymentIntent
      amount: stripe_payment_intent.amount,
      amount_received: stripe_payment_intent.amount_received,
      currency: stripe_payment_intent.currency,
      application_fee_amount: stripe_payment_intent.application_fee_amount,
      # Status
      status: stripe_payment_intent.status,
      amount_refunded: charge && Map.get(charge, :amount_refunded, 0),
      # Customer & receipt info
      customer_email:
        charge && Map.get(charge, :billing_details) &&
          Map.get(charge.billing_details, :email),
      receipt_email: charge && Map.get(charge, :receipt_email),
      receipt_number: charge && Map.get(charge, :receipt_number),
      receipt_url: charge && Map.get(charge, :receipt_url),
      description: stripe_payment_intent.description,
      # Payment method details
      payment_method: stripe_payment_intent.payment_method,
      payment_method_type: payment_method && Map.get(payment_method, :type),
      card_brand: card_details && Map.get(card_details, :brand),
      card_last4: card_details && Map.get(card_details, :last4),
      card_exp_month: card_details && Map.get(card_details, :exp_month),
      card_exp_year: card_details && Map.get(card_details, :exp_year),
      card_fingerprint: card_details && Map.get(card_details, :fingerprint),
      # Metadata
      stripe_metadata: stripe_payment_intent.metadata || %{},
      livemode: stripe_payment_intent.livemode
    }

    # Add balance transaction data if available (from expanded charge)
    base_attrs =
      if is_struct(balance_transaction) do
        available_on =
          case Map.get(balance_transaction, :available_on) do
            ts when is_integer(ts) ->
              ts
              |> DateTime.from_unix!(:second)
              |> DateTime.to_date()

            _ ->
              nil
          end

        Map.merge(base_attrs, %{
          balance_transaction_id: Map.get(balance_transaction, :id),
          fee: Map.get(balance_transaction, :fee),
          net: Map.get(balance_transaction, :net),
          fee_details: Map.get(balance_transaction, :fee_details),
          available_on: available_on,
          exchange_rate: Map.get(balance_transaction, :exchange_rate)
        })
      else
        # Store balance transaction ID as string if not expanded
        bt_id =
          charge && Map.get(charge, :balance_transaction)

        Map.put(base_attrs, :balance_transaction_id, bt_id)
      end

    # Merge with additional attrs
    attrs = Map.merge(base_attrs, attrs)

    changeset(payment, attrs)
  end

  @doc """
  Changeset for updating payment status from Stripe webhook
  Extracts comprehensive payment data including fees, card details, and receipts
  """
  def update_from_stripe_changeset(payment, stripe_payment_intent) do
    # Get the charge object from latest_charge or charges list
    charge =
      cond do
        # Check if latest_charge is expanded (struct)
        is_struct(stripe_payment_intent.latest_charge) ->
          stripe_payment_intent.latest_charge

        # Check if latest_charge is a string ID
        is_binary(stripe_payment_intent.latest_charge) ->
          nil

        # Fallback to charges list if available (from webhook events)
        is_map(Map.get(stripe_payment_intent, :charges)) ->
          stripe_payment_intent.charges
          |> Map.get(:data, [])
          |> List.first()

        true ->
          nil
      end

    # Get payment method details (using struct field access)
    payment_method = charge && Map.get(charge, :payment_method_details)
    card_details = payment_method && Map.get(payment_method, :card)

    # Get balance transaction (if expanded as struct)
    balance_transaction = charge && Map.get(charge, :balance_transaction)

    # Build comprehensive attributes
    attrs = %{
      # Status
      status: stripe_payment_intent.status,
      # Stripe IDs
      stripe_charge_id: charge && Map.get(charge, :id),
      # Amounts
      amount_received: stripe_payment_intent.amount_received,
      amount_refunded: charge && Map.get(charge, :amount_refunded, 0),
      # Customer & receipt info
      customer_email:
        charge && Map.get(charge, :billing_details) &&
          Map.get(charge.billing_details, :email),
      receipt_email: charge && Map.get(charge, :receipt_email),
      receipt_number: charge && Map.get(charge, :receipt_number),
      receipt_url: charge && Map.get(charge, :receipt_url),
      # Payment method details
      payment_method: stripe_payment_intent.payment_method,
      payment_method_type: payment_method && Map.get(payment_method, :type),
      card_brand: card_details && Map.get(card_details, :brand),
      card_last4: card_details && Map.get(card_details, :last4),
      card_exp_month: card_details && Map.get(card_details, :exp_month),
      card_exp_year: card_details && Map.get(card_details, :exp_year),
      card_fingerprint: card_details && Map.get(card_details, :fingerprint),
      # Failure info
      failure_code:
        stripe_payment_intent.last_payment_error &&
          Map.get(stripe_payment_intent.last_payment_error, :code),
      failure_message:
        stripe_payment_intent.last_payment_error &&
          Map.get(stripe_payment_intent.last_payment_error, :message)
    }

    # Add balance transaction data if available (from expanded charge)
    attrs =
      if is_struct(balance_transaction) do
        available_on =
          case Map.get(balance_transaction, :available_on) do
            ts when is_integer(ts) ->
              ts
              |> DateTime.from_unix!(:second)
              |> DateTime.to_date()

            _ ->
              nil
          end

        Map.merge(attrs, %{
          balance_transaction_id: Map.get(balance_transaction, :id),
          fee: Map.get(balance_transaction, :fee),
          net: Map.get(balance_transaction, :net),
          fee_details: Map.get(balance_transaction, :fee_details),
          available_on: available_on,
          exchange_rate: Map.get(balance_transaction, :exchange_rate)
        })
      else
        # Store balance transaction ID as string if not expanded
        bt_id = charge && Map.get(charge, :balance_transaction)
        Map.put(attrs, :balance_transaction_id, bt_id)
      end

    # Filter out nil values to preserve existing data
    # Only update fields that have actual values from Stripe
    attrs = Map.reject(attrs, fn {_key, value} -> is_nil(value) end)

    payment
    |> cast(attrs, [
      # Status
      :status,
      # Stripe IDs
      :stripe_charge_id,
      :balance_transaction_id,
      # Amounts
      :amount_received,
      :amount_refunded,
      # Fees (from balance transaction)
      :fee,
      :net,
      :fee_details,
      :available_on,
      :exchange_rate,
      # Customer & receipt
      :customer_email,
      :receipt_email,
      :receipt_number,
      :receipt_url,
      # Payment method
      :payment_method,
      :payment_method_type,
      :card_brand,
      :card_last4,
      :card_exp_month,
      :card_exp_year,
      :card_fingerprint,
      # Failures
      :failure_code,
      :failure_message
    ])
    |> validate_required([:status])
    |> validate_inclusion(:status, @valid_statuses)
  end

  @doc """
  Appends an event to the payment's event history.

  Events are stored in chronological order with the newest events at the end.
  The status is automatically updated based on the event.

  ## Examples

      iex> append_event(payment, "payment_intent.succeeded", %{amount: 1000})
      %Payment{events: [...], status: "succeeded"}

  """
  def append_event(%__MODULE__{} = payment, event_type, event_data \\ %{}) do
    # Use string keys to match what derive_status_from_events expects
    event = %{
      "type" => event_type,
      "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "data" => event_data
    }

    new_events = (payment.events || []) ++ [event]
    new_status = derive_status_from_events(new_events)

    payment
    |> Ecto.Changeset.change(events: new_events, status: new_status)
  end

  @doc """
  Derives the current payment status from the event history.

  The status is simply the type of the most recent event.
  This keeps status always in sync with events.
  """
  def derive_status_from_events([]), do: "payment_created"

  def derive_status_from_events(events) when is_list(events) do
    # Status is the most recent event type
    case List.last(events) do
      %{"type" => event_type} -> event_type
      _ -> "unknown"
    end
  end

  @doc """
  Checks if the payment is in a succeeded state.
  """
  def succeeded?(%__MODULE__{status: status}) do
    status in ["payment_intent.succeeded", "charge.succeeded", "succeeded"]
  end

  @doc """
  Checks if the payment has been refunded based on events.
  """
  def refunded?(%__MODULE__{events: events, amount_refunded: amount_refunded})
      when is_list(events) and is_integer(amount_refunded) do
    # Check if any refund events exist and amount_refunded > 0
    has_refund_event =
      Enum.any?(events, fn event ->
        event["type"] in ["charge.refunded", "charge.refund.updated"]
      end)

    has_refund_event && amount_refunded > 0
  end

  def refunded?(_), do: false

  @doc """
  Checks if the payment is fully refunded (amount_refunded == amount).
  """
  def fully_refunded?(%__MODULE__{amount: amount, amount_refunded: amount_refunded})
      when is_integer(amount) and is_integer(amount_refunded) do
    amount_refunded >= amount
  end

  def fully_refunded?(_), do: false
end
