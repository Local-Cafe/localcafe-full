defmodule LocalCafe.CH_Repo do
  use Ecto.Repo,
    otp_app: :local_cafe,
    adapter: Ecto.Adapters.ClickHouse
end
