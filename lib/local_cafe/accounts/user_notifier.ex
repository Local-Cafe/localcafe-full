defmodule LocalCafe.Accounts.UserNotifier do
  import Swoosh.Email

  alias LocalCafe.Mailer
  alias LocalCafe.Accounts.User

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"LocalCafe", "no-reploy@localcafe.org"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Update email instructions", """

    ==============================

    Hi #{user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to log in with a magic link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(user.email, "Log in instructions", """

    ==============================

    Hi #{user.email},

    You can log into your account by visiting the URL below:

    #{url}

    If you didn't request this email, please ignore this.

    ==============================
    """)
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirmation instructions", """

    ==============================

    Hi #{user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver order confirmation email with magic link to view the order.
  """
  def deliver_order_confirmation(user, order, url) do
    user_name = user.name || user.email

    deliver(user.email, "Order Confirmation - LocalCafe", """

    ==============================

    Hi #{user_name},

    Thank you for your order!

    Order Number: #{order.order_number}
    Total: $#{:erlang.float_to_binary(order.subtotal / 100, decimals: 2)}

    Click the link below to view your order and log in to your account:

    #{url}

    This link will expire in 15 minutes.

    ==============================
    """)
  end
end
