defmodule LocalCafeWeb.WebhookController do
  use LocalCafeWeb, :controller

  alias LocalCafe.Billing
  alias LocalCafe.Billing.StripeService
  alias LocalCafe.Orders
  alias LocalCafe.Repo

  require Logger

  @doc """
  Handles Stripe webhook events.

  Stripe will send POST requests to this endpoint when payment-related events occur.
  We verify the signature and process relevant events.
  """
  def stripe(conn, _params) do
    # Get the raw body from conn.assigns (cached by CacheBodyReader)
    payload = conn.assigns[:raw_body]
    signature = get_req_header(conn, "stripe-signature") |> List.first()

    # Log incoming webhook details for debugging
    Logger.info("Stripe webhook received")
    Logger.debug("Raw body cached: #{!is_nil(payload)}")

    # Check if we have the required data
    cond do
      is_nil(payload) ->
        Logger.error("Raw body not found in conn.assigns - CacheBodyReader may not be working")

        conn
        |> put_status(:bad_request)
        |> json(%{error: "Unable to read request body"})

      is_nil(signature) ->
        Logger.error("No Stripe-Signature header found in request")

        conn
        |> put_status(:bad_request)
        |> json(%{error: "Missing signature header"})

      true ->
        Logger.debug("Payload size: #{byte_size(payload)} bytes")
        Logger.debug("Payload first 100 chars: #{String.slice(payload, 0, 100)}")
        Logger.debug("Payload last 50 chars: #{String.slice(payload, -50, 50)}")
        Logger.debug("Signature header value: #{signature}")

        case StripeService.verify_webhook_signature(payload, signature) do
          {:ok, event} ->
            Logger.info("Webhook signature verified successfully for event: #{event.type}")
            handle_event(event)

            conn
            |> put_status(:ok)
            |> json(%{received: true})

          {:error, reason} ->
            Logger.error("Webhook signature verification failed: #{inspect(reason)}")
            Logger.error("Payload length at verification: #{byte_size(payload)}")
            Logger.error("Signature at verification: #{inspect(signature)}")

            conn
            |> put_status(:bad_request)
            |> json(%{error: "Invalid signature"})
        end
    end
  end

  # Handle different Stripe event types
  defp handle_event(%{type: "payment_intent.succeeded"} = event) do
    payment_intent = event.data.object
    Logger.info("Payment succeeded: #{payment_intent.id}")

    case Billing.get_payment_by_stripe_id(payment_intent.id) do
      nil ->
        Logger.warning("Payment not found for payment_intent: #{payment_intent.id}")

      payment ->
        # Retrieve expanded payment intent with balance transaction data
        case StripeService.retrieve_payment_intent_expanded(payment_intent.id) do
          {:ok, expanded_payment_intent} ->
            # First update the payment with Stripe data
            case Billing.update_payment_from_stripe(payment, expanded_payment_intent) do
              {:ok, updated_payment} ->
                # Then append the event to track the state change
                case Billing.append_payment_event(
                       updated_payment,
                       "payment_intent.succeeded",
                       %{
                         amount: payment_intent.amount,
                         amount_received: payment_intent.amount_received,
                         currency: payment_intent.currency,
                         payment_method: payment_intent.payment_method,
                         status: payment_intent.status
                       }
                     ) do
                  {:ok, final_payment} ->
                    Logger.info("Payment #{final_payment.id} succeeded and event recorded")

                    # Auto-confirm the order if payment has an associated order
                    confirm_order_if_exists(final_payment)

                  {:error, changeset} ->
                    Logger.error("Failed to append event: #{inspect(changeset.errors)}")
                end

              {:error, changeset} ->
                Logger.error("Failed to update payment: #{inspect(changeset.errors)}")
            end

          {:error, _error} ->
            # Fallback to basic update if expanded retrieval fails
            Logger.warning("Failed to retrieve expanded payment intent, using basic data")

            case Billing.update_payment_from_stripe(payment, payment_intent) do
              {:ok, updated_payment} ->
                # Append event
                case Billing.append_payment_event(
                       updated_payment,
                       "payment_intent.succeeded",
                       %{amount: payment_intent.amount}
                     ) do
                  {:ok, final_payment} ->
                    Logger.info("Payment #{final_payment.id} succeeded (basic data)")

                    # Auto-confirm the order if payment has an associated order
                    confirm_order_if_exists(final_payment)

                  {:error, changeset} ->
                    Logger.error("Failed to append event: #{inspect(changeset.errors)}")
                end

              {:error, changeset} ->
                Logger.error("Failed to update payment: #{inspect(changeset.errors)}")
            end
        end
    end

    :ok
  end

  defp handle_event(%{type: "payment_intent.payment_failed"} = event) do
    payment_intent = event.data.object
    Logger.info("Payment failed: #{payment_intent.id}")

    case Billing.get_payment_by_stripe_id(payment_intent.id) do
      nil ->
        Logger.warning("Payment not found for payment_intent: #{payment_intent.id}")

      payment ->
        case Billing.update_payment_from_stripe(payment, payment_intent) do
          {:ok, updated_payment} ->
            # Append event
            Billing.append_payment_event(
              updated_payment,
              "payment_intent.payment_failed",
              %{
                failure_code: payment_intent.last_payment_error[:code],
                failure_message: payment_intent.last_payment_error[:message]
              }
            )

            Logger.info("Payment #{updated_payment.id} failed and event recorded")

          {:error, changeset} ->
            Logger.error("Failed to update payment: #{inspect(changeset.errors)}")
        end
    end
  end

  defp handle_event(%{type: "payment_intent.canceled"} = event) do
    payment_intent = event.data.object
    Logger.info("Payment canceled: #{payment_intent.id}")

    case Billing.get_payment_by_stripe_id(payment_intent.id) do
      nil ->
        Logger.warning("Payment not found for payment_intent: #{payment_intent.id}")

      payment ->
        case Billing.update_payment_from_stripe(payment, payment_intent) do
          {:ok, updated_payment} ->
            Billing.append_payment_event(updated_payment, "payment_intent.canceled", %{})
            Logger.info("Payment #{updated_payment.id} canceled and event recorded")

          {:error, changeset} ->
            Logger.error("Failed to update payment: #{inspect(changeset.errors)}")
        end
    end
  end

  defp handle_event(%{type: "payment_intent.processing"} = event) do
    payment_intent = event.data.object
    Logger.info("Payment processing: #{payment_intent.id}")

    case Billing.get_payment_by_stripe_id(payment_intent.id) do
      nil ->
        Logger.warning("Payment not found for payment_intent: #{payment_intent.id}")

      payment ->
        case Billing.update_payment_from_stripe(payment, payment_intent) do
          {:ok, updated_payment} ->
            Billing.append_payment_event(updated_payment, "payment_intent.processing", %{})
            Logger.info("Payment #{updated_payment.id} processing and event recorded")

          {:error, changeset} ->
            Logger.error("Failed to update payment: #{inspect(changeset.errors)}")
        end
    end
  end

  defp handle_event(%{type: "payment_intent.requires_action"} = event) do
    payment_intent = event.data.object
    Logger.info("Payment requires action: #{payment_intent.id}")

    case Billing.get_payment_by_stripe_id(payment_intent.id) do
      nil ->
        Logger.warning("Payment not found for payment_intent: #{payment_intent.id}")

      payment ->
        case Billing.update_payment_from_stripe(payment, payment_intent) do
          {:ok, updated_payment} ->
            Billing.append_payment_event(updated_payment, "payment_intent.requires_action", %{})
            Logger.info("Payment #{updated_payment.id} requires action and event recorded")

          {:error, changeset} ->
            Logger.error("Failed to update payment: #{inspect(changeset.errors)}")
        end
    end
  end

  defp handle_event(%{type: "charge.succeeded"} = event) do
    charge = event.data.object
    Logger.info("Charge succeeded: #{charge.id}")

    # Get payment by payment_intent ID from the charge
    case Billing.get_payment_by_stripe_id(charge.payment_intent) do
      nil ->
        Logger.warning(
          "Payment not found for charge: #{charge.id} (payment_intent: #{charge.payment_intent})"
        )

      payment ->
        case StripeService.retrieve_payment_intent_expanded(charge.payment_intent) do
          {:ok, expanded_payment_intent} ->
            case Billing.update_payment_from_stripe(payment, expanded_payment_intent) do
              {:ok, updated_payment} ->
                # Get payment method details from charge
                payment_method = charge.payment_method_details
                card_details = payment_method && Map.get(payment_method, :card)

                # Merge charge metadata into payment's stripe_metadata
                # This captures metadata that might only be on the charge (e.g., donation message)
                merged_metadata =
                  Map.merge(updated_payment.stripe_metadata || %{}, charge.metadata || %{})

                # Update payment with merged metadata
                payment_with_metadata =
                  case Billing.update_payment_metadata(updated_payment, merged_metadata) do
                    {:ok, p} -> p
                    {:error, _} -> updated_payment
                  end

                Billing.append_payment_event(
                  payment_with_metadata,
                  "charge.succeeded",
                  %{
                    charge_id: charge.id,
                    amount: charge.amount,
                    amount_captured: charge.amount_captured,
                    payment_method_type: payment_method && Map.get(payment_method, :type),
                    card_brand: card_details && Map.get(card_details, :brand),
                    card_last4: card_details && Map.get(card_details, :last4),
                    receipt_url: charge.receipt_url,
                    charge_metadata: charge.metadata
                  }
                )

                Logger.info("Payment #{updated_payment.id} charge succeeded and event recorded")

              {:error, changeset} ->
                Logger.error("Failed to update payment: #{inspect(changeset.errors)}")
            end

          {:error, _error} ->
            Logger.warning("Failed to retrieve expanded payment intent for charge.succeeded")
        end
    end
  end

  defp handle_event(%{type: "charge.failed"} = event) do
    charge = event.data.object
    Logger.info("Charge failed: #{charge.id}")

    # Get payment by payment_intent ID from the charge
    case Billing.get_payment_by_stripe_id(charge.payment_intent) do
      nil ->
        Logger.warning(
          "Payment not found for charge: #{charge.id} (payment_intent: #{charge.payment_intent})"
        )

      payment ->
        case StripeService.retrieve_payment_intent_expanded(charge.payment_intent) do
          {:ok, expanded_payment_intent} ->
            case Billing.update_payment_from_stripe(payment, expanded_payment_intent) do
              {:ok, updated_payment} ->
                Billing.append_payment_event(
                  updated_payment,
                  "charge.failed",
                  %{
                    charge_id: charge.id,
                    failure_code: charge.failure_code,
                    failure_message: charge.failure_message
                  }
                )

                Logger.info("Payment #{updated_payment.id} charge failed and event recorded")

              {:error, changeset} ->
                Logger.error("Failed to update payment: #{inspect(changeset.errors)}")
            end

          {:error, _error} ->
            Logger.warning("Failed to retrieve expanded payment intent for charge.failed")
        end
    end
  end

  defp handle_event(%{type: "charge.refunded"} = event) do
    charge = event.data.object
    Logger.info("Charge refunded: #{charge.id} (amount: #{charge.amount_refunded})")

    # Get payment by payment_intent ID from the charge
    case Billing.get_payment_by_stripe_id(charge.payment_intent) do
      nil ->
        Logger.warning(
          "Payment not found for charge: #{charge.id} (payment_intent: #{charge.payment_intent})"
        )

      payment ->
        case StripeService.retrieve_payment_intent_expanded(charge.payment_intent) do
          {:ok, expanded_payment_intent} ->
            case Billing.update_payment_from_stripe(payment, expanded_payment_intent) do
              {:ok, updated_payment} ->
                # Safely extract refund IDs from charge
                refund_ids =
                  case charge.refunds do
                    %{data: refunds} when is_list(refunds) ->
                      Enum.map(refunds, & &1.id)

                    _ ->
                      []
                  end

                Billing.append_payment_event(
                  updated_payment,
                  "charge.refunded",
                  %{
                    charge_id: charge.id,
                    amount_refunded: charge.amount_refunded,
                    refund_ids: refund_ids
                  }
                )

                Logger.info(
                  "Payment #{updated_payment.id} refund recorded (amount: #{updated_payment.amount_refunded})"
                )

                # Update order status to refunded if payment is fully refunded
                update_order_on_refund(updated_payment)

              {:error, changeset} ->
                Logger.error("Failed to update payment: #{inspect(changeset.errors)}")
            end

          {:error, _error} ->
            Logger.warning("Failed to retrieve expanded payment intent for charge.refunded")
        end
    end
  end

  defp handle_event(%{type: "charge.updated"} = event) do
    charge = event.data.object
    Logger.info("Charge updated: #{charge.id}")

    # Get payment by payment_intent ID from the charge
    case Billing.get_payment_by_stripe_id(charge.payment_intent) do
      nil ->
        Logger.warning(
          "Payment not found for charge: #{charge.id} (payment_intent: #{charge.payment_intent})"
        )

      payment ->
        # Fetch expanded payment intent to get comprehensive data
        case StripeService.retrieve_payment_intent_expanded(charge.payment_intent) do
          {:ok, expanded_payment_intent} ->
            case Billing.update_payment_from_stripe(payment, expanded_payment_intent) do
              {:ok, updated_payment} ->
                Logger.info("Updated payment #{updated_payment.id} from charge.updated")

              {:error, changeset} ->
                Logger.error("Failed to update payment: #{inspect(changeset.errors)}")
            end

          {:error, _error} ->
            Logger.warning("Failed to retrieve expanded payment intent for charge.updated")
        end
    end
  end

  defp handle_event(%{type: event_type}) do
    Logger.info("Unhandled webhook event type: #{event_type}")
  end

  # Helper to auto-confirm order when payment succeeds
  defp confirm_order_if_exists(payment) do
    # Preload the order association
    payment = Repo.preload(payment, :order)

    case payment.order do
      nil ->
        Logger.debug("Payment #{payment.id} has no associated order, skipping auto-confirm")
        :ok

      order ->
        # Only auto-confirm if order is still in pending status
        if order.status == "pending" do
          Logger.info(
            "Auto-confirming order #{order.order_number} (#{order.id}) after successful payment"
          )

          # Create a system admin scope for internal operations
          # This mocks an admin user for automated order confirmation
          system_admin = %{admin: true}
          scope = %LocalCafe.Accounts.Scope{user: system_admin}

          case Orders.update_order_status(scope, order, "paid") do
            {:ok, paid_order} ->
              Logger.info(
                "Order #{paid_order.order_number} auto-paid via webhook (was: pending, now: paid)"
              )

              :ok

            {:error, reason} ->
              Logger.error(
                "Failed to auto-confirm order #{order.order_number}: #{inspect(reason)}"
              )

              :error
          end
        else
          Logger.info(
            "Order #{order.order_number} is already in '#{order.status}' status, not auto-confirming"
          )

          :ok
        end
    end
  end

  # Helper to update order status when payment is refunded
  defp update_order_on_refund(payment) do
    alias LocalCafe.Billing.Payment

    # Preload the order association
    payment = Repo.preload(payment, :order)

    case payment.order do
      nil ->
        Logger.debug("Payment #{payment.id} has no associated order, skipping refund status update")
        :ok

      order ->
        # Only update if payment is fully refunded
        if Payment.fully_refunded?(payment) do
          Logger.info(
            "Updating order #{order.order_number} (#{order.id}) to refunded status after full refund"
          )

          # Create a system admin scope for internal operations
          system_admin = %{admin: true}
          scope = %LocalCafe.Accounts.Scope{user: system_admin}

          case Orders.update_order_status(scope, order, "refunded") do
            {:ok, refunded_order} ->
              Logger.info(
                "Order #{refunded_order.order_number} marked as refunded via webhook (was: #{order.status}, now: refunded)"
              )

              :ok

            {:error, reason} ->
              Logger.error(
                "Failed to update order #{order.order_number} to refunded: #{inspect(reason)}"
              )

              :error
          end
        else
          Logger.info(
            "Order #{order.order_number} has partial refund (#{payment.amount_refunded}/#{payment.amount}), not updating status"
          )

          :ok
        end
    end
  end
end
