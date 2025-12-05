defmodule LocalCafeWeb.PaymentController do
  use LocalCafeWeb, :controller

  alias LocalCafe.Billing

  def index(conn, _params) do
    scope = conn.assigns.current_scope
    payments = Billing.list_payments_with_details(scope)

    render(conn, :index, payments: payments, page_title: "Payment History")
  end
end
