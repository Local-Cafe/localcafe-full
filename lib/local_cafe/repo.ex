defmodule LocalCafe.Repo do
  use Ecto.Repo,
    otp_app: :local_cafe,
    adapter: Ecto.Adapters.Postgres
end
