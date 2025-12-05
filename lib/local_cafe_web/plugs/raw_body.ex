defmodule LocalCafeWeb.Plugs.RawBody do
  @moduledoc """
  Plug to store the raw request body in conn assigns.
  This is needed for Stripe webhook signature verification.
  """

  require Logger

  def init(opts), do: opts

  def call(conn, _opts) do
    Logger.debug("RawBody plug: Reading request body")

    case Plug.Conn.read_body(conn) do
      {:ok, body, conn} ->
        Logger.debug("RawBody plug: Successfully read #{byte_size(body)} bytes")
        Logger.debug("RawBody plug: Body first 100 chars: #{String.slice(body, 0, 100)}")
        Plug.Conn.assign(conn, :raw_body, body)

      {:more, partial_body, conn} ->
        Logger.warning(
          "RawBody plug: Received partial body (#{byte_size(partial_body)} bytes), reading more..."
        )

        # Read the rest of the body
        read_full_body(conn, partial_body)

      {:error, reason} ->
        Logger.error("RawBody plug: Failed to read body: #{inspect(reason)}")
        conn
    end
  end

  # Helper to read full body when it comes in chunks
  defp read_full_body(conn, acc) do
    case Plug.Conn.read_body(conn) do
      {:ok, body, conn} ->
        full_body = acc <> body

        Logger.debug(
          "RawBody plug: Finished reading full body (#{byte_size(full_body)} bytes total)"
        )

        Plug.Conn.assign(conn, :raw_body, full_body)

      {:more, partial_body, conn} ->
        Logger.debug(
          "RawBody plug: Reading more... (accumulated #{byte_size(acc <> partial_body)} bytes)"
        )

        read_full_body(conn, acc <> partial_body)

      {:error, reason} ->
        Logger.error("RawBody plug: Failed to read remaining body: #{inspect(reason)}")
        Plug.Conn.assign(conn, :raw_body, acc)
    end
  end
end
