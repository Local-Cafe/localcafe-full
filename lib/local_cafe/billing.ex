defmodule LocalCafe.Billing do
  @moduledoc """
  The Billing context.
  """

  import Ecto.Query, warn: false
  alias LocalCafe.Repo

  alias LocalCafe.Billing.Payment
  alias LocalCafe.Accounts.Scope

  require Logger

  @doc """
  Subscribes to scoped notifications about any payment changes.

  The broadcasted messages match the pattern:

    * {:created, %Payment{}}
    * {:updated, %Payment{}}
    * {:deleted, %Payment{}}

  """
  def subscribe_payments(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(LocalCafe.PubSub, "user:#{key}:payments")
  end

  defp broadcast_payment(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(LocalCafe.PubSub, "user:#{key}:payments", message)
  end

  @doc """
  Returns the list of payments.

  ## Examples

      iex> list_payments(scope)
      [%Payment{}, ...]

  """
  def list_payments(%Scope{} = scope) do
    Repo.all_by(Payment, user_id: scope.user.id)
  end

  @doc """
  Returns the list of payments with all related details preloaded.
  Filters out incomplete payments (requires_payment_method and payment_intent.created statuses).

  ## Examples

      iex> list_payments_with_details(scope)
      [%Payment{donations: [...], post_purchases: [%PostPurchase{post: ...}]}, ...]

  """
  def list_payments_with_details(%Scope{} = scope) do
    from(p in Payment,
      where: p.user_id == ^scope.user.id,
      where: p.status not in ["requires_payment_method", "payment_intent.created"],
      order_by: [desc: p.inserted_at]
    )
    |> Repo.all()
    |> Enum.map(fn payment ->
      # Clear large fields not needed for display to save memory
      %{payment | events: [], stripe_metadata: %{}, metadata: %{}, fee_details: []}
    end)
  end

  @doc """
  Gets a single payment.

  Raises `Ecto.NoResultsError` if the Payment does not exist.

  ## Examples

      iex> get_payment!(scope, 123)
      %Payment{}

      iex> get_payment!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_payment!(%Scope{} = scope, id) do
    Repo.get_by!(Payment, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a payment.

  ## Examples

      iex> create_payment(scope, %{field: value})
      {:ok, %Payment{}}

      iex> create_payment(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_payment(%Scope{} = scope, attrs) do
    attrs = Map.put(attrs, :user_id, scope.user.id)

    with {:ok, payment = %Payment{}} <-
           %Payment{}
           |> Payment.changeset(attrs)
           |> Repo.insert() do
      broadcast_payment(scope, {:created, payment})
      {:ok, payment}
    end
  end

  @doc """
  Updates a payment.

  ## Examples

      iex> update_payment(scope, payment, %{field: new_value})
      {:ok, %Payment{}}

      iex> update_payment(scope, payment, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_payment(%Scope{} = scope, %Payment{} = payment, attrs) do
    true = payment.user_id == scope.user.id

    with {:ok, payment = %Payment{}} <-
           payment
           |> Payment.changeset(attrs)
           |> Repo.update() do
      broadcast_payment(scope, {:updated, payment})
      {:ok, payment}
    end
  end

  @doc """
  Deletes a payment.

  ## Examples

      iex> delete_payment(scope, payment)
      {:ok, %Payment{}}

      iex> delete_payment(scope, payment)
      {:error, %Ecto.Changeset{}}

  """
  def delete_payment(%Scope{} = scope, %Payment{} = payment) do
    true = payment.user_id == scope.user.id

    with {:ok, payment = %Payment{}} <-
           Repo.delete(payment) do
      broadcast_payment(scope, {:deleted, payment})
      {:ok, payment}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking payment changes.

  ## Examples

      iex> change_payment(scope, payment)
      %Ecto.Changeset{data: %Payment{}}

  """
  def change_payment(%Scope{} = scope, %Payment{} = payment, attrs \\ %{}) do
    true = payment.user_id == scope.user.id

    Payment.changeset(payment, attrs)
  end

  # Guest user payment functions (no authentication required)

  @doc """
  Creates a payment without requiring authentication.
  Used for guest donations and other guest payments.

  ## Examples

      iex> create_guest_payment(%{amount: 1000, ...})
      {:ok, %Payment{}}

      iex> create_guest_payment(%{amount: -100})
      {:error, %Ecto.Changeset{}}

  """
  def create_guest_payment(attrs) do
    # Create payment with initial status
    case %Payment{}
         |> Payment.changeset(attrs)
         |> Repo.insert() do
      {:ok, payment} ->
        # Append initial event - use payment_intent.created as the event type
        # Include the actual Stripe status in the event data
        case payment
             |> Payment.append_event("payment_intent.created", %{
               amount: payment.amount,
               currency: payment.currency,
               status: payment.status,
               payment_intent_id: payment.stripe_payment_intent_id
             })
             |> Repo.update() do
          {:ok, updated_payment} ->
            {:ok, updated_payment}

          {:error, changeset} ->
            Logger.error(
              "Failed to append initial event to payment: #{inspect(changeset.errors)}"
            )

            # Return the payment even if event append fails
            {:ok, payment}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Gets a payment by its Stripe payment intent ID.
  Used for webhook processing.

  ## Examples

      iex> get_payment_by_stripe_id("pi_123")
      %Payment{}

      iex> get_payment_by_stripe_id("pi_nonexistent")
      nil

  """
  def get_payment_by_stripe_id(stripe_payment_intent_id) do
    Repo.get_by(Payment, stripe_payment_intent_id: stripe_payment_intent_id)
  end

  @doc """
  Creates a payment from a Stripe payment intent.
  Optionally associates it with a user.

  ## Examples

      iex> create_payment_from_stripe(payment_intent, user)
      {:ok, %Payment{}}

      iex> create_payment_from_stripe(payment_intent, nil)
      {:ok, %Payment{}}

  """
  def create_payment_from_stripe(stripe_payment_intent, user \\ nil) do
    # Extract tip_amount from metadata
    tip_amount =
      case stripe_payment_intent.metadata do
        %{"tip_amount" => tip} when is_binary(tip) -> String.to_integer(tip)
        %{tip_amount: tip} when is_integer(tip) -> tip
        _ -> 0
      end

    attrs = %{
      stripe_payment_intent_id: stripe_payment_intent.id,
      stripe_customer_id: stripe_payment_intent.customer,
      amount: stripe_payment_intent.amount,
      tip_amount: tip_amount,
      currency: String.upcase(stripe_payment_intent.currency),
      status: stripe_payment_intent.status,
      stripe_metadata: stripe_payment_intent.metadata || %{},
      customer_email: stripe_payment_intent.receipt_email
    }

    attrs = if user, do: Map.put(attrs, :user_id, user.id), else: attrs

    # Create payment with initial status
    case %Payment{}
         |> Payment.changeset(attrs)
         |> Repo.insert() do
      {:ok, payment} ->
        # Append initial event
        case payment
             |> Payment.append_event("payment_intent.created", %{
               amount: payment.amount,
               currency: payment.currency,
               status: payment.status,
               payment_intent_id: payment.stripe_payment_intent_id
             })
             |> Repo.update() do
          {:ok, updated_payment} ->
            {:ok, updated_payment}

          {:error, changeset} ->
            Logger.error(
              "Failed to append initial event to payment: #{inspect(changeset.errors)}"
            )

            # Return the payment even if event append fails
            {:ok, payment}
        end

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Links a payment to an order.

  ## Examples

      iex> link_payment_to_order(payment, order_id)
      {:ok, %Payment{}}

  """
  def link_payment_to_order(%Payment{} = payment, order_id) do
    payment
    |> Ecto.Changeset.change(order_id: order_id)
    |> Repo.update()
  end

  @doc """
  Updates a payment from a Stripe webhook event.
  Does not require authentication since webhooks are verified separately.

  ## Examples

      iex> update_payment_from_stripe(payment, stripe_payment_intent)
      {:ok, %Payment{}}

  """
  def update_payment_from_stripe(%Payment{} = payment, stripe_payment_intent) do
    payment
    |> Payment.update_from_stripe_changeset(stripe_payment_intent)
    |> Repo.update()
  end

  @doc """
  Updates a payment's metadata (for webhooks/admin - no scope required).

  ## Examples

      iex> update_payment_metadata(payment, %{"key" => "value"})
      {:ok, %Payment{}}

  """
  def update_payment_metadata(%Payment{} = payment, metadata) do
    payment
    |> Ecto.Changeset.change(stripe_metadata: metadata)
    |> Repo.update()
  end

  @doc """
  Appends an event to a payment's event history and updates its status.

  This is used by webhooks to track the full lifecycle of a payment.

  ## Examples

      iex> append_payment_event(payment, "payment_intent.succeeded", %{amount: 1000})
      {:ok, %Payment{}}

  """
  def append_payment_event(%Payment{} = payment, event_type, event_data \\ %{}) do
    payment
    |> Payment.append_event(event_type, event_data)
    |> Repo.update()
  end

  @doc """
  Gets billing statistics for the admin dashboard.

  ## Examples

      iex> get_billing_stats()
      %{total_revenue: 10000, total_fees: 320, total_net: 9680, payment_count: 5}

  """
  def get_billing_stats do
    # Succeeded payments (completed, not refunded)
    # Exclude payments with "charge.refunded" status or amount_refunded > 0
    succeeded_payments =
      from(p in Payment,
        where:
          p.status in ["payment_intent.succeeded", "charge.succeeded", "succeeded"] and
            p.status != "charge.refunded" and
            (p.amount_refunded == 0 or is_nil(p.amount_refunded))
      )

    succeeded_revenue =
      from(p in succeeded_payments, select: sum(p.amount))
      |> Repo.one()
      |> Kernel.||(0)

    succeeded_fees =
      from(p in succeeded_payments, select: sum(p.fee))
      |> Repo.one()
      |> Kernel.||(0)

    succeeded_net =
      from(p in succeeded_payments, select: sum(p.net))
      |> Repo.one()
      |> Kernel.||(0)

    succeeded_count =
      from(p in succeeded_payments, select: count(p.id))
      |> Repo.one()
      |> Kernel.||(0)

    succeeded_tips =
      from(p in succeeded_payments, select: sum(p.tip_amount))
      |> Repo.one()
      |> Kernel.||(0)

    # Refunded payments (succeeded but refunded)
    # A payment is refunded if status is "charge.refunded" or if succeeded with amount_refunded > 0
    refunded_payments =
      from(p in Payment,
        where:
          p.status == "charge.refunded" or
            (p.status in ["payment_intent.succeeded", "charge.succeeded", "succeeded"] and
               p.amount_refunded > 0)
      )

    refunded_amount =
      from(p in refunded_payments, select: sum(p.amount_refunded))
      |> Repo.one()
      |> Kernel.||(0)

    refunded_count =
      from(p in refunded_payments, select: count(p.id))
      |> Repo.one()
      |> Kernel.||(0)

    # Pending payments (in progress - created, requires action, confirmation, or processing)
    pending_payments =
      from(p in Payment,
        where:
          p.status in [
            "payment_intent.created",
            "payment_intent.processing",
            "payment_intent.requires_action",
            "requires_payment_method",
            "requires_confirmation",
            "requires_action",
            "processing",
            "requires_capture"
          ]
      )

    pending_revenue =
      from(p in pending_payments, select: sum(p.amount))
      |> Repo.one()
      |> Kernel.||(0)

    pending_count =
      from(p in pending_payments, select: count(p.id))
      |> Repo.one()
      |> Kernel.||(0)

    # Failed/Canceled payments
    failed_count =
      from(p in Payment,
        where:
          p.status in [
            "payment_intent.payment_failed",
            "payment_intent.canceled",
            "charge.failed",
            "canceled"
          ],
        select: count(p.id)
      )
      |> Repo.one()
      |> Kernel.||(0)

    # Total
    total_count =
      from(p in Payment, select: count(p.id))
      |> Repo.one()
      |> Kernel.||(0)

    %{
      succeeded_revenue: succeeded_revenue,
      succeeded_fees: succeeded_fees,
      succeeded_net: succeeded_net,
      succeeded_count: succeeded_count,
      succeeded_tips: succeeded_tips,
      refunded_amount: refunded_amount,
      refunded_count: refunded_count,
      pending_revenue: pending_revenue,
      pending_count: pending_count,
      failed_count: failed_count,
      total_count: total_count
    }
  end

  @doc """
  Gets the payment associated with an order.

  Returns nil if no payment is found for the order.

  ## Examples

      iex> get_payment_by_order("order-id-123")
      %Payment{}

      iex> get_payment_by_order("non-existent")
      nil

  """
  def get_payment_by_order(order_id) do
    Payment
    |> where([p], p.order_id == ^order_id)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Processes a refund for an order's payment through Stripe.

  This function:
  1. Retrieves the payment associated with the order
  2. Creates a refund via Stripe
  3. Updates the local payment record with the refund information

  ## Parameters

    - order: The order struct to refund
    - opts: Optional keyword list with:
      - amount: Amount to refund in cents (defaults to full refund)
      - reason: Reason for refund (:duplicate, :fraudulent, or :requested_by_customer)

  ## Examples

      iex> process_refund(order)
      {:ok, %Payment{}}

      iex> process_refund(order, amount: 1000, reason: :requested_by_customer)
      {:ok, %Payment{}}

  ## Returns

    - {:ok, payment} - Successfully refunded
    - {:error, :no_payment} - No payment found for the order
    - {:error, :already_refunded} - Payment has already been fully refunded
    - {:error, :payment_not_succeeded} - Payment hasn't succeeded yet
    - {:error, reason} - Stripe API error or database error

  """
  def process_refund(order, opts \\ []) do
    alias LocalCafe.Billing.StripeService

    with {:payment, payment} when not is_nil(payment) <- {:payment, get_payment_by_order(order.id)},
         {:succeeded, true} <- {:succeeded, Payment.succeeded?(payment)},
         {:not_refunded, false} <- {:not_refunded, Payment.fully_refunded?(payment)},
         {:stripe_refund, {:ok, _stripe_refund}} <-
           {:stripe_refund,
            StripeService.refund_payment(
              payment.stripe_payment_intent_id,
              Keyword.merge(opts,
                metadata: %{
                  order_id: order.id,
                  order_number: order.order_number
                }
              )
            )},
         # Retrieve the updated payment intent from Stripe to get the refund amount
         {:retrieve, {:ok, updated_payment_intent}} <-
           {:retrieve,
            StripeService.retrieve_payment_intent_expanded(payment.stripe_payment_intent_id)},
         {:update, {:ok, updated_payment}} <-
           {:update, update_payment_from_stripe(payment, updated_payment_intent)} do
      Logger.info("Successfully processed refund for order #{order.order_number}")
      {:ok, updated_payment}
    else
      {:payment, nil} ->
        Logger.warning("No payment found for order #{order.id}")
        {:error, :no_payment}

      {:succeeded, false} ->
        Logger.warning("Payment for order #{order.id} has not succeeded yet")
        {:error, :payment_not_succeeded}

      {:not_refunded, true} ->
        Logger.warning("Payment for order #{order.id} has already been fully refunded")
        {:error, :already_refunded}

      {:stripe_refund, {:error, reason}} ->
        Logger.error("Failed to create Stripe refund for order #{order.id}: #{inspect(reason)}")
        {:error, reason}

      {:retrieve, {:error, reason}} ->
        Logger.error(
          "Failed to retrieve updated payment intent for order #{order.id}: #{inspect(reason)}"
        )

        {:error, reason}

      {:update, {:error, changeset}} ->
        Logger.error(
          "Failed to update payment record for order #{order.id}: #{inspect(changeset.errors)}"
        )

        {:error, changeset}
    end
  end
end
