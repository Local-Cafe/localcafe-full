defmodule LocalCafe.BillingTest do
  use LocalCafe.DataCase

  alias LocalCafe.Billing

  describe "payments" do
    alias LocalCafe.Billing.Payment

    import LocalCafe.AccountsFixtures, only: [user_scope_fixture: 0]
    import LocalCafe.BillingFixtures

    @invalid_attrs %{
      status: nil,
      description: nil,
      metadata: nil,
      currency: nil,
      stripe_payment_intent_id: nil,
      stripe_charge_id: nil,
      amount: nil,
      payment_method: nil,
      customer_email: nil
    }

    test "list_payments/1 returns all scoped payments" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      payment = payment_fixture(scope)
      other_payment = payment_fixture(other_scope)
      assert Billing.list_payments(scope) == [payment]
      assert Billing.list_payments(other_scope) == [other_payment]
    end

    test "get_payment!/2 returns the payment with given id" do
      scope = user_scope_fixture()
      payment = payment_fixture(scope)
      other_scope = user_scope_fixture()
      assert Billing.get_payment!(scope, payment.id) == payment
      assert_raise Ecto.NoResultsError, fn -> Billing.get_payment!(other_scope, payment.id) end
    end

    test "create_payment/2 with valid data creates a payment" do
      valid_attrs = %{
        status: "some status",
        description: "some description",
        metadata: %{},
        currency: "some currency",
        stripe_payment_intent_id: "some stripe_payment_intent_id",
        stripe_charge_id: "some stripe_charge_id",
        amount: 42,
        payment_method: "some payment_method",
        customer_email: "some customer_email"
      }

      scope = user_scope_fixture()

      assert {:ok, %Payment{} = payment} = Billing.create_payment(scope, valid_attrs)
      assert payment.status == "some status"
      assert payment.description == "some description"
      assert payment.metadata == %{}
      assert payment.currency == "some currency"
      assert payment.stripe_payment_intent_id == "some stripe_payment_intent_id"
      assert payment.stripe_charge_id == "some stripe_charge_id"
      assert payment.amount == 42
      assert payment.payment_method == "some payment_method"
      assert payment.customer_email == "some customer_email"
      assert payment.user_id == scope.user.id
    end

    test "create_payment/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Billing.create_payment(scope, @invalid_attrs)
    end

    test "update_payment/3 with valid data updates the payment" do
      scope = user_scope_fixture()
      payment = payment_fixture(scope)

      update_attrs = %{
        status: "some updated status",
        description: "some updated description",
        metadata: %{},
        currency: "some updated currency",
        stripe_payment_intent_id: "some updated stripe_payment_intent_id",
        stripe_charge_id: "some updated stripe_charge_id",
        amount: 43,
        payment_method: "some updated payment_method",
        customer_email: "some updated customer_email"
      }

      assert {:ok, %Payment{} = payment} = Billing.update_payment(scope, payment, update_attrs)
      assert payment.status == "some updated status"
      assert payment.description == "some updated description"
      assert payment.metadata == %{}
      assert payment.currency == "some updated currency"
      assert payment.stripe_payment_intent_id == "some updated stripe_payment_intent_id"
      assert payment.stripe_charge_id == "some updated stripe_charge_id"
      assert payment.amount == 43
      assert payment.payment_method == "some updated payment_method"
      assert payment.customer_email == "some updated customer_email"
    end

    test "update_payment/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      payment = payment_fixture(scope)

      assert_raise MatchError, fn ->
        Billing.update_payment(other_scope, payment, %{})
      end
    end

    test "update_payment/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      payment = payment_fixture(scope)
      assert {:error, %Ecto.Changeset{}} = Billing.update_payment(scope, payment, @invalid_attrs)
      assert payment == Billing.get_payment!(scope, payment.id)
    end

    test "delete_payment/2 deletes the payment" do
      scope = user_scope_fixture()
      payment = payment_fixture(scope)
      assert {:ok, %Payment{}} = Billing.delete_payment(scope, payment)
      assert_raise Ecto.NoResultsError, fn -> Billing.get_payment!(scope, payment.id) end
    end

    test "delete_payment/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      payment = payment_fixture(scope)
      assert_raise MatchError, fn -> Billing.delete_payment(other_scope, payment) end
    end

    test "change_payment/2 returns a payment changeset" do
      scope = user_scope_fixture()
      payment = payment_fixture(scope)
      assert %Ecto.Changeset{} = Billing.change_payment(scope, payment)
    end
  end
end
