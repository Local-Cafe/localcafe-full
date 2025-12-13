defmodule LocalCafe.Billing.StripeService do
  @moduledoc """
  Service module for interacting with the Stripe API.
  Handles customer creation and payment intent management.
  """

  require Logger

  @doc """
  Creates a new Stripe customer or retrieves an existing one.

  This function intelligently handles customer creation:
  1. If the user already has a stripe_customer_id, verify it exists and return it
  2. If not, search Stripe for an existing customer with the user's email
  3. If found, link it to the user and return it
  4. If not found, create a new customer and link it to the user

  ## Examples

      iex> create_or_get_customer(user)
      {:ok, %Stripe.Customer{id: "cus_123..."}}

  """
  def create_or_get_customer(
        %{email: email, id: user_id, stripe_customer_id: stripe_customer_id} = user
      ) do
    cond do
      # User already has a stripe_customer_id stored - verify it exists
      stripe_customer_id != nil ->
        Logger.info("User #{user_id} has existing Stripe customer ID: #{stripe_customer_id}")

        case Stripe.Customer.retrieve(stripe_customer_id) do
          {:ok, customer} ->
            Logger.info("Successfully retrieved existing Stripe customer #{customer.id}")
            {:ok, customer}

          {:error, %Stripe.Error{code: :resource_missing}} ->
            Logger.warning(
              "Stored customer ID #{stripe_customer_id} not found in Stripe, will search/create new"
            )

            search_or_create_customer(email, user_id, user)

          {:error, error} ->
            Logger.error(
              "Failed to retrieve Stripe customer #{stripe_customer_id}: #{inspect(error)}"
            )

            {:error, error}
        end

      # No stored customer ID - search Stripe for existing customer by email
      true ->
        search_or_create_customer(email, user_id, user)
    end
  end

  # Fallback for when user struct is not provided (backwards compatibility)
  def create_or_get_customer(email, user_id) when is_binary(email) do
    Logger.warning(
      "create_or_get_customer/2 called without user struct - consider updating to pass full user"
    )

    # Search for existing customer by email
    case Stripe.Customer.list(%{email: email, limit: 1}) do
      {:ok, %{data: [customer | _]}} ->
        Logger.info("Found existing Stripe customer #{customer.id} for #{email}")
        {:ok, customer}

      {:ok, %{data: []}} ->
        # No existing customer found - create new one
        metadata = if user_id, do: %{user_id: user_id}, else: %{}

        case Stripe.Customer.create(%{email: email, metadata: metadata}) do
          {:ok, customer} ->
            Logger.info("Created Stripe customer #{customer.id} for #{email}")
            {:ok, customer}

          {:error, error} ->
            Logger.error("Failed to create Stripe customer for #{email}: #{inspect(error)}")
            {:error, error}
        end

      {:error, error} ->
        Logger.error("Failed to search for Stripe customer: #{inspect(error)}")
        {:error, error}
    end
  end

  # Helper to search for existing customer by email or create a new one
  defp search_or_create_customer(email, user_id, user) do
    case Stripe.Customer.list(%{email: email, limit: 1}) do
      {:ok, %{data: [customer | _]}} ->
        Logger.info("Found existing Stripe customer #{customer.id} for #{email}")

        # Store the customer ID on the user record
        case LocalCafe.Accounts.update_user_stripe_customer_id(user, customer.id) do
          {:ok, _updated_user} ->
            Logger.info("Linked Stripe customer #{customer.id} to user #{user_id}")

          {:error, error} ->
            Logger.error("Failed to link Stripe customer to user: #{inspect(error)}")
        end

        {:ok, customer}

      {:ok, %{data: []}} ->
        # No existing customer found - create new one
        Logger.info("No existing Stripe customer for #{email}, creating new")

        case Stripe.Customer.create(%{
               email: email,
               metadata: %{user_id: user_id}
             }) do
          {:ok, customer} ->
            Logger.info("Created Stripe customer #{customer.id} for #{email}")

            # Store the customer ID on the user record
            case LocalCafe.Accounts.update_user_stripe_customer_id(user, customer.id) do
              {:ok, _updated_user} ->
                Logger.info("Linked new Stripe customer #{customer.id} to user #{user_id}")

              {:error, error} ->
                Logger.error("Failed to link Stripe customer to user: #{inspect(error)}")
            end

            {:ok, customer}

          {:error, error} ->
            Logger.error("Failed to create Stripe customer for #{email}: #{inspect(error)}")
            {:error, error}
        end

      {:error, error} ->
        Logger.error("Failed to search for Stripe customer: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Creates a new Stripe customer.

  ## Parameters

    - params: Map with customer details (email, metadata, etc.)

  ## Examples

      iex> create_customer(%{email: "user@example.com", metadata: %{user_id: "123"}})
      {:ok, %Stripe.Customer{}}

  """
  def create_customer(params) do
    Stripe.Customer.create(params)
  end

  @doc """
  Creates a Stripe payment intent.

  ## Parameters

    - amount: Amount in cents (integer)
    - customer_id: Stripe customer ID (optional - can be nil for guest checkouts)
    - metadata: Map of metadata to attach to the payment intent
    - opts: Optional keyword list with:
      - description: Description of the payment (appears in dashboard and receipts)
      - statement_descriptor: Text on customer's credit card statement (max 22 chars)
      - receipt_email: Email address to send receipt to (required if no customer)

  ## Examples

      iex> create_payment_intent(1000, "cus_123", %{donation_id: "abc"}, description: "Donation")
      {:ok, %Stripe.PaymentIntent{}}

      iex> create_payment_intent(1000, nil, %{}, description: "Guest Donation", receipt_email: "user@example.com")
      {:ok, %Stripe.PaymentIntent{}}

  """
  def create_payment_intent(amount, customer_id, metadata \\ %{}, opts \\ []) do
    params =
      %{
        amount: amount,
        currency: "usd",
        metadata: metadata,
        # Automatically capture payment when authorized
        capture_method: :automatic
      }
      |> maybe_add_customer(customer_id)
      |> maybe_add_description(Keyword.get(opts, :description))
      |> maybe_add_statement_descriptor_suffix(Keyword.get(opts, :statement_descriptor_suffix))
      |> maybe_add_receipt_email(Keyword.get(opts, :receipt_email))

    case Stripe.PaymentIntent.create(params) do
      {:ok, payment_intent} ->
        Logger.info("Created payment intent #{payment_intent.id} for $#{amount / 100}")
        {:ok, payment_intent}

      {:error, error} ->
        Logger.error("Failed to create payment intent: #{inspect(error)}")
        {:error, error}
    end
  end

  # Helper to add customer only if provided
  defp maybe_add_customer(params, nil), do: params
  defp maybe_add_customer(params, customer_id), do: Map.put(params, :customer, customer_id)

  # Helper to add description only if provided
  defp maybe_add_description(params, nil), do: params
  defp maybe_add_description(params, description), do: Map.put(params, :description, description)

  # Helper to add statement descriptor suffix only if provided
  defp maybe_add_statement_descriptor_suffix(params, nil), do: params

  defp maybe_add_statement_descriptor_suffix(params, suffix),
    do: Map.put(params, :statement_descriptor_suffix, suffix)

  # Helper to add receipt email only if provided
  defp maybe_add_receipt_email(params, nil), do: params
  defp maybe_add_receipt_email(params, email), do: Map.put(params, :receipt_email, email)

  @doc """
  Retrieves a payment intent from Stripe.

  ## Examples

      iex> retrieve_payment_intent("pi_123")
      {:ok, %Stripe.PaymentIntent{}}

  """
  def retrieve_payment_intent(payment_intent_id) do
    case Stripe.PaymentIntent.retrieve(payment_intent_id) do
      {:ok, payment_intent} ->
        {:ok, payment_intent}

      {:error, error} ->
        Logger.error("Failed to retrieve payment intent #{payment_intent_id}: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Updates a payment intent with new parameters.

  ## Examples

      iex> update_payment_intent("pi_123", %{customer: "cus_123"})
      {:ok, %Stripe.PaymentIntent{}}

  """
  def update_payment_intent(payment_intent_id, params) do
    case Stripe.PaymentIntent.update(payment_intent_id, params) do
      {:ok, payment_intent} ->
        {:ok, payment_intent}

      {:error, error} ->
        Logger.error("Failed to update payment intent #{payment_intent_id}: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Retrieves a payment intent with expanded charge data.
  This includes charge details, payment method information, and balance transaction.

  ## Examples

      iex> retrieve_payment_intent_expanded("pi_123")
      {:ok, %Stripe.PaymentIntent{latest_charge: %Stripe.Charge{...}}}

  """
  def retrieve_payment_intent_expanded(payment_intent_id) do
    case Stripe.PaymentIntent.retrieve(payment_intent_id, %{
           expand: ["latest_charge.balance_transaction"]
         }) do
      {:ok, payment_intent} ->
        {:ok, payment_intent}

      {:error, error} ->
        Logger.error(
          "Failed to retrieve expanded payment intent #{payment_intent_id}: #{inspect(error)}"
        )

        {:error, error}
    end
  end

  @doc """
  Retrieves a balance transaction from Stripe.
  Balance transactions contain fee information and net amounts.

  ## Examples

      iex> retrieve_balance_transaction("txn_123")
      {:ok, %Stripe.BalanceTransaction{}}

  """
  def retrieve_balance_transaction(balance_transaction_id) do
    case Stripe.BalanceTransaction.retrieve(balance_transaction_id) do
      {:ok, balance_transaction} ->
        {:ok, balance_transaction}

      {:error, error} ->
        Logger.error(
          "Failed to retrieve balance transaction #{balance_transaction_id}: #{inspect(error)}"
        )

        {:error, error}
    end
  end

  @doc """
  Creates a refund for a payment intent or charge.

  ## Parameters

    - payment_intent_id: The Stripe payment intent ID to refund
    - opts: Optional keyword list with:
      - amount: Amount to refund in cents (defaults to full refund if not specified)
      - reason: Reason for refund (:duplicate, :fraudulent, or :requested_by_customer)
      - metadata: Map of metadata to attach to the refund

  ## Examples

      iex> refund_payment("pi_123")
      {:ok, %Stripe.Refund{}}

      iex> refund_payment("pi_123", amount: 1000, reason: :requested_by_customer)
      {:ok, %Stripe.Refund{}}

  """
  def refund_payment(payment_intent_id, opts \\ []) do
    params =
      %{payment_intent: payment_intent_id}
      |> maybe_add_refund_amount(Keyword.get(opts, :amount))
      |> maybe_add_refund_reason(Keyword.get(opts, :reason))
      |> maybe_add_refund_metadata(Keyword.get(opts, :metadata))

    case Stripe.Refund.create(params) do
      {:ok, refund} ->
        Logger.info("Created refund #{refund.id} for payment intent #{payment_intent_id}")
        {:ok, refund}

      {:error, error} ->
        Logger.error("Failed to create refund for #{payment_intent_id}: #{inspect(error)}")
        {:error, error}
    end
  end

  # Helper to add refund amount only if provided (otherwise defaults to full refund)
  defp maybe_add_refund_amount(params, nil), do: params
  defp maybe_add_refund_amount(params, amount), do: Map.put(params, :amount, amount)

  # Helper to add refund reason only if provided
  defp maybe_add_refund_reason(params, nil), do: params
  defp maybe_add_refund_reason(params, reason), do: Map.put(params, :reason, reason)

  # Helper to add refund metadata only if provided
  defp maybe_add_refund_metadata(params, nil), do: params
  defp maybe_add_refund_metadata(params, metadata), do: Map.put(params, :metadata, metadata)

  @doc """
  Verifies a Stripe webhook signature.

  ## Parameters

    - payload: The raw request body
    - signature: The Stripe-Signature header value

  ## Examples

      iex> verify_webhook_signature(payload, signature)
      {:ok, %Stripe.Event{}}

      iex> verify_webhook_signature(payload, "invalid")
      {:error, "Invalid signature"}

  """
  def verify_webhook_signature(payload, signature) do
    signing_secret = Application.get_env(:stripity_stripe, :signing_secret)

    # Log verification attempt details
    Logger.debug("Starting webhook signature verification")
    Logger.debug("Signing secret configured: #{!is_nil(signing_secret)}")

    if signing_secret do
      # Mask the secret for logging (show first 7 chars which is the "whsec_" prefix)
      masked_secret =
        String.slice(signing_secret, 0, 7) <> "..." <> String.slice(signing_secret, -4, 4)

      Logger.debug("Signing secret (masked): #{masked_secret}")
    else
      Logger.error("Signing secret is not configured!")
    end

    Logger.debug("Payload type: #{inspect(is_binary(payload))}")

    Logger.debug(
      "Payload size for verification: #{if is_binary(payload), do: byte_size(payload), else: "not binary"}"
    )

    Logger.debug("Signature type: #{inspect(is_binary(signature))}")
    Logger.debug("Signature value for verification: #{inspect(signature)}")

    case Stripe.Webhook.construct_event(payload, signature, signing_secret) do
      {:ok, event} ->
        Logger.info("Successfully constructed event from webhook: #{event.id} (#{event.type})")
        {:ok, event}

      {:error, error} ->
        Logger.error("Webhook signature verification failed in construct_event")
        Logger.error("Error type: #{inspect(error)}")
        Logger.error("Error message: #{inspect(error)}")

        # Log additional context about what was passed to construct_event
        Logger.error("Verification context:")
        Logger.error("  - Payload was binary: #{is_binary(payload)}")

        Logger.error(
          "  - Payload length: #{if is_binary(payload), do: byte_size(payload), else: "N/A"}"
        )

        Logger.error("  - Signature was binary: #{is_binary(signature)}")
        Logger.error("  - Signature value: #{inspect(signature)}")
        Logger.error("  - Signing secret configured: #{!is_nil(signing_secret)}")

        {:error, error}
    end
  end
end
