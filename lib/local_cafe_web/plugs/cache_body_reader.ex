defmodule LocalCafeWeb.CacheBodyReader do
  @moduledoc """
  Custom body reader for Plug.Parsers that caches the raw body before parsing.

  This is needed for webhook signature verification, where we need access to the
  exact raw body that was sent (before any parsing or modification).

  Stripe webhooks require the raw body to verify signatures, but Plug.Parsers
  consumes the body during JSON parsing. This module caches the raw body in
  conn.assigns[:raw_body] before parsing occurs.
  """

  require Logger

  @doc """
  Reads the body and caches it in conn.assigns before returning it for parsing.

  This function is called by Plug.Parsers instead of the default Plug.Conn.read_body/2.
  """
  def read_body(conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        Logger.debug("CacheBodyReader: Caching #{byte_size(body)} bytes")
        conn = Plug.Conn.assign(conn, :raw_body, body)
        {:ok, body, conn}

      {:more, partial_body, conn} ->
        Logger.debug("CacheBodyReader: Received partial body (#{byte_size(partial_body)} bytes)")
        # For chunked bodies, we need to read all chunks first
        case read_full_body(conn, partial_body, opts) do
          {:ok, full_body, conn} ->
            Logger.debug(
              "CacheBodyReader: Finished reading full body (#{byte_size(full_body)} bytes)"
            )

            conn = Plug.Conn.assign(conn, :raw_body, full_body)
            {:ok, full_body, conn}

          {:error, reason} ->
            Logger.error("CacheBodyReader: Failed to read full body: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} = error ->
        Logger.error("CacheBodyReader: Failed to read body: #{inspect(reason)}")
        error
    end
  end

  # Helper to read full body when it comes in chunks
  defp read_full_body(conn, acc, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        {:ok, acc <> body, conn}

      {:more, partial_body, conn} ->
        read_full_body(conn, acc <> partial_body, opts)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
