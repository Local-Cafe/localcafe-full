defmodule LocalCafeWeb.UserSessionHTML do
  use LocalCafeWeb, :html

  embed_templates "user_session_html/*"

  defp local_mail_adapter? do
    Application.get_env(:local_cafe, LocalCafe.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
