defmodule LocalCafeWeb.UserSessionController do
  use LocalCafeWeb, :controller

  alias LocalCafe.Accounts
  alias LocalCafeWeb.UserAuth

  def new(conn, _params) do
    email = get_in(conn.assigns, [:current_scope, Access.key(:user), Access.key(:email)])
    form = Phoenix.Component.to_form(%{"email" => email}, as: "user")

    render(conn, :new, form: form, page_title: "Log In")
  end

  # magic link login
  def create(conn, %{"user" => %{"token" => token} = user_params} = params) do
    info =
      case params do
        %{"_action" => "confirmed"} -> "User confirmed successfully."
        _ -> "Welcome back!"
      end

    case Accounts.login_user_by_magic_link(token) do
      {:ok, {user, _expired_tokens}} ->
        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "The link is invalid or it has expired.")
        |> render(:new, form: Phoenix.Component.to_form(%{}, as: "user"), page_title: "Log In")
    end
  end

  # email + password login
  def create(conn, %{"user" => %{"email" => email, "password" => password} = user_params}) do
    if user = Accounts.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, "Welcome back!")
      |> UserAuth.log_in_user(user, user_params)
    else
      form = Phoenix.Component.to_form(user_params, as: "user")

      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> render(:new, form: form, page_title: "Log In")
    end
  end

  # magic link request
  def create(conn, %{"user" => %{"email" => email}}) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    conn
    |> put_flash(:info, info)
    |> redirect(to: ~p"/users/log-in")
  end

  def confirm(conn, %{"token" => token}) do
    # Check if this is an order confirmation token first
    case Accounts.get_user_by_order_token(token) do
      {_user, order_id} ->
        # This is an order confirmation token - log in and redirect to order
        Accounts.login_user_by_order_token(token)
        |> case do
          {:ok, {user, _expired_tokens}} ->
            conn
            |> UserAuth.log_in_user(user)
            |> put_flash(:info, "Logged in successfully! Here is your order.")
            |> redirect(to: ~p"/my-orders/#{order_id}")

          {:error, :not_found} ->
            conn
            |> put_flash(:error, "This login link is invalid or has expired.")
            |> redirect(to: ~p"/users/log-in")
        end

      nil ->
        # Not an order token, check if it's a regular magic link
        # Auto-confirm and auto-login the user
        case Accounts.login_user_by_magic_link(token) do
          {:ok, {user, _expired_tokens}} ->
            conn
            |> put_flash(:info, "Welcome back!")
            |> UserAuth.log_in_user(user, %{"remember_me" => "true"})

          {:error, :not_found} ->
            conn
            |> put_flash(:error, "Magic link is invalid or it has expired.")
            |> redirect(to: ~p"/users/log-in")
        end
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
