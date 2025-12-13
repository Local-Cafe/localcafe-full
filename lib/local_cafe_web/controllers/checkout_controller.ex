defmodule LocalCafeWeb.CheckoutController do
  use LocalCafeWeb, :controller

  alias LocalCafe.{Cart, Orders, Accounts, Billing}
  alias LocalCafe.Billing.StripeService

  require Logger

  def new(conn, _params) do
    cart = Cart.get_cart(conn)

    if cart == [] do
      conn
      |> put_flash(:error, "Your cart is empty")
      |> redirect(to: ~p"/#menu")
    else
      subtotal = Cart.cart_subtotal(cart)
      user = conn.assigns[:current_scope] && conn.assigns.current_scope.user

      # If user is logged in, go directly to payment
      # If guest, show customer info form first
      if user do
        redirect(conn, to: ~p"/checkout/payment")
      else
        render(conn, :new,
          cart: cart,
          subtotal: subtotal,
          page_title: "Checkout"
        )
      end
    end
  end

  def payment(conn, params) do
    cart = Cart.get_cart(conn)

    if cart == [] do
      conn
      |> put_flash(:error, "Your cart is empty")
      |> redirect(to: ~p"/#menu")
    else
      subtotal = Cart.cart_subtotal(cart)

      # Get tip amount from params (in cents)
      tip_amount =
        case params["tip_amount"] do
          nil -> 0
          "" -> 0
          amount -> String.to_integer(amount)
        end

      # Store tip in session for later use
      conn = Plug.Conn.put_session(conn, :tip_amount, tip_amount)

      # Calculate total (subtotal + tip)
      total = subtotal + tip_amount

      user = conn.assigns[:current_scope] && conn.assigns.current_scope.user

      # Get or create user from params (for guests) or use logged-in user
      user_result =
        cond do
          # Already logged in
          user ->
            {:ok, user}

          # Guest provided email
          params["customer_email"] && params["customer_email"] != "" ->
            Accounts.get_or_create_user_by_email(
              params["customer_email"],
              params["customer_name"]
            )

          # No user info (shouldn't happen)
          true ->
            {:error, :no_user_info}
        end

      case user_result do
        {:ok, user} ->
          # Create or get Stripe customer
          case StripeService.create_or_get_customer(user) do
            {:ok, customer} ->
              # Create payment intent with customer
              metadata = %{
                cart_item_count: length(cart),
                customer_email: user.email,
                tip_amount: tip_amount,
                subtotal: subtotal
              }

              opts = [
                description: "LocalCafe Order",
                receipt_email: user.email
              ]

              case StripeService.create_payment_intent(total, customer.id, metadata, opts) do
                {:ok, payment_intent} ->
                  # Create payment record
                  case Billing.create_payment_from_stripe(payment_intent, user) do
                    {:ok, _payment} ->
                      # Get Stripe publishable key
                      stripe_config = Application.get_env(:local_cafe, :stripe)
                      stripe_publishable_key = Keyword.get(stripe_config, :publishable_key)

                      render(conn, :payment,
                        cart: cart,
                        subtotal: subtotal,
                        tip_amount: tip_amount,
                        total: total,
                        client_secret: payment_intent.client_secret,
                        stripe_publishable_key: stripe_publishable_key,
                        customer_name: params["customer_name"] || user.name,
                        customer_email: user.email,
                        page_title: "Payment"
                      )

                    {:error, _changeset} ->
                      Logger.error("Failed to create payment record")

                      conn
                      |> put_flash(
                        :error,
                        "There was an error initializing payment. Please try again."
                      )
                      |> redirect(to: ~p"/cart")
                  end

                {:error, _error} ->
                  Logger.error("Failed to create payment intent")

                  conn
                  |> put_flash(
                    :error,
                    "There was an error initializing payment. Please try again."
                  )
                  |> redirect(to: ~p"/cart")
              end

            {:error, _error} ->
              Logger.error("Failed to create/get Stripe customer")

              conn
              |> put_flash(:error, "There was an error creating customer. Please try again.")
              |> redirect(to: ~p"/cart")
          end

        {:error, _} ->
          conn
          |> put_flash(:error, "Please provide a valid email address.")
          |> redirect(to: ~p"/checkout")
      end
    end
  end

  def create(conn, %{"order" => order_params, "payment_intent_id" => payment_intent_id}) do
    cart = Cart.get_cart(conn)

    if cart == [] do
      conn
      |> put_flash(:error, "Your cart is empty")
      |> redirect(to: ~p"/#menu")
    else
      # Verify the payment intent succeeded
      case StripeService.retrieve_payment_intent(payment_intent_id) do
        {:ok, payment_intent} ->
          if payment_intent.status == "succeeded" do
            # Payment succeeded, create the order
            customer_note = order_params["customer_note"]
            customer_name = order_params["customer_name"]
            customer_email = order_params["customer_email"]

            # Get payment to find associated user
            payment = Billing.get_payment_by_stripe_id(payment_intent_id)

            user =
              if payment && payment.user_id,
                do: LocalCafe.Repo.get(Accounts.User, payment.user_id),
                else: nil

            # Add user_id to order attributes if we have a user
            order_attrs =
              cart
              |> Cart.cart_to_order_attrs(customer_note, customer_name, customer_email)
              |> then(fn attrs ->
                if user, do: Map.put(attrs, :user_id, user.id), else: attrs
              end)

            case Orders.create_order(conn.assigns[:current_scope], order_attrs) do
              {:ok, order} ->
                # Link payment to order
                final_order =
                  case Billing.get_payment_by_stripe_id(payment_intent_id) do
                    nil ->
                      Logger.warning("Payment not found for payment_intent: #{payment_intent_id}")
                      order

                    payment ->
                      Billing.link_payment_to_order(payment, order.id)

                      # Update payment intent metadata and description with order details
                      order_url = url(~p"/my-orders/#{order.id}")

                      case StripeService.update_payment_intent(payment_intent_id, %{
                             description: "LocalCafe Order #{order.order_number} - #{order_url}",
                             metadata: %{
                               order_id: order.id,
                               order_number: order.order_number,
                               order_url: order_url
                             }
                           }) do
                        {:ok, _} ->
                          Logger.info(
                            "Updated payment intent #{payment_intent_id} with order URL"
                          )

                        {:error, error} ->
                          Logger.error(
                            "Failed to update payment intent metadata: #{inspect(error)}"
                          )
                      end

                      # Auto-mark order as paid since payment already succeeded
                      if order.status == "pending" do
                        # Create a system admin scope for internal operations
                        system_admin = %{admin: true}
                        scope = %Accounts.Scope{user: system_admin}

                        case Orders.update_order_status(scope, order, "paid") do
                          {:ok, paid_order} ->
                            Logger.info(
                              "Order #{paid_order.order_number} marked as paid after successful payment"
                            )

                            paid_order

                          {:error, reason} ->
                            Logger.error(
                              "Failed to mark order #{order.order_number} as paid: #{inspect(reason)}"
                            )

                            order
                        end
                      else
                        order
                      end
                  end

                conn =
                  conn
                  |> Cart.clear_cart()
                  |> Plug.Conn.delete_session(:tip_amount)

                # Send order confirmation email if we have a user
                if user do
                  Accounts.deliver_order_confirmation(user, final_order, fn token ->
                    url(~p"/users/log-in/#{token}")
                  end)
                end

                # Determine redirect and flash message based on authentication status
                if conn.assigns[:current_scope] && conn.assigns.current_scope.user do
                  # User is logged in - redirect to order page normally
                  conn
                  |> put_flash(:info, "Order placed successfully!")
                  |> redirect(to: ~p"/my-orders/#{final_order.id}")
                else
                  # Guest user - generate a temporary view token and redirect with it
                  view_token = Phoenix.Token.sign(conn, "order_view", final_order.id)

                  flash_message =
                    if user do
                      "Order placed successfully! Check your email (#{user.email}) for order confirmation and login link."
                    else
                      "Order placed successfully!"
                    end

                  conn
                  |> put_flash(:info, flash_message)
                  |> redirect(to: ~p"/my-orders/#{final_order.id}?#{%{token: view_token}}")
                end

              {:error, _changeset} ->
                Logger.error("Failed to create order after payment succeeded")

                conn
                |> put_flash(
                  :error,
                  "There was an error creating your order. Please contact support with payment ID: #{payment_intent_id}"
                )
                |> redirect(to: ~p"/")
            end
          else
            # Payment not successful
            Logger.error("Payment intent status is #{payment_intent.status}, not succeeded")

            conn
            |> put_flash(:error, "Payment was not successful. Please try again.")
            |> redirect(to: ~p"/checkout")
          end

        {:error, _error} ->
          Logger.error("Failed to retrieve payment intent: #{payment_intent_id}")

          conn
          |> put_flash(:error, "There was an error verifying your payment. Please try again.")
          |> redirect(to: ~p"/checkout")
      end
    end
  end
end
