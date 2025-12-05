defmodule LocalCafe.BillingFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `LocalCafe.Billing` context.
  """

  @doc """
  Generate a unique payment stripe_payment_intent_id.
  """
  def unique_payment_stripe_payment_intent_id,
    do: "some stripe_payment_intent_id#{System.unique_integer([:positive])}"

  @doc """
  Generate a payment.
  """
  def payment_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        amount: 1000,
        currency: "usd",
        customer_email: "test@example.com",
        description: "Test payment",
        metadata: %{},
        payment_method: "card",
        status: "succeeded",
        stripe_charge_id: "ch_test_#{System.unique_integer([:positive])}",
        stripe_payment_intent_id: unique_payment_stripe_payment_intent_id()
      })

    {:ok, payment} = LocalCafe.Billing.create_payment(scope, attrs)
    payment
  end
end
