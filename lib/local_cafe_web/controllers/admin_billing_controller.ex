defmodule LocalCafeWeb.AdminBillingController do
  use LocalCafeWeb, :controller
  alias LocalCafe.Repo
  alias LocalCafe.Billing
  alias LocalCafe.Billing.Payment
  import Ecto.Query

  def index(conn, params) do
    # Check if user is admin
    if conn.assigns.current_scope && conn.assigns.current_scope.user &&
         conn.assigns.current_scope.user.admin do
      # Get filter parameter (default to "all")
      filter = Map.get(params, "filter", "all")

      # Get payments based on filter
      payments =
        case filter do
          "succeeded" ->
            from(p in Payment,
              where:
                p.status in ["payment_intent.succeeded", "charge.succeeded", "succeeded"] and
                  p.status != "charge.refunded" and
                  (p.amount_refunded == 0 or is_nil(p.amount_refunded)),
              order_by: [desc: p.inserted_at]
            )
            |> Repo.all()

          "pending" ->
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
                ],
              order_by: [desc: p.inserted_at]
            )
            |> Repo.all()

          "refunded" ->
            from(p in Payment,
              where:
                p.status == "charge.refunded" or
                  (p.status in ["payment_intent.succeeded", "charge.succeeded", "succeeded"] and
                     p.amount_refunded > 0),
              order_by: [desc: p.inserted_at]
            )
            |> Repo.all()

          "failed" ->
            from(p in Payment,
              where:
                p.status in [
                  "payment_intent.payment_failed",
                  "payment_intent.canceled",
                  "charge.failed",
                  "canceled"
                ],
              order_by: [desc: p.inserted_at]
            )
            |> Repo.all()

          "all" ->
            from(p in Payment, order_by: [desc: p.inserted_at])
            |> Repo.all()

          _ ->
            from(p in Payment, order_by: [desc: p.inserted_at])
            |> Repo.all()
        end

      # Get billing stats
      billing_stats = Billing.get_billing_stats()

      render(conn, :index,
        payments: payments,
        filter: filter,
        billing_stats: billing_stats,
        page_title: "Admin - Billing"
      )
    else
      conn
      |> put_flash(:error, "You must be an admin to access this page.")
      |> redirect(to: ~p"/")
    end
  end

  def show(conn, %{"id" => id}) do
    # Check if user is admin
    if conn.assigns.current_scope && conn.assigns.current_scope.user &&
         conn.assigns.current_scope.user.admin do
      # Get payment with events (admin can see any payment)
      payment = Repo.get!(Payment, id)

      render(conn, :show,
        payment: payment,
        page_title: "Payment Details"
      )
    else
      conn
      |> put_flash(:error, "You must be an admin to access this page.")
      |> redirect(to: ~p"/")
    end
  end
end
