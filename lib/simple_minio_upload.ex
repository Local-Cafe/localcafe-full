defmodule SimpleMinioUpload do
  @moduledoc """
  Dependency-free MinIO Binary Upload presigner using HTTP PUT sigv4
  https://docs.aws.amazon.com/AmazonS3/latest/API/sigv4-post-example.html
  This was heavly influnced by https://github.com/srivathsanmurali/minio_ex so all the credit goes to them for their fine work.
  """

  @doc """
    Signs a binary upload.
  """

  @sign_v4_algo "AWS4-HMAC-SHA256"
  @unsigned_payload "UNSIGNED-PAYLOAD"

  def sign_binary_upload(config, opts) do
    {:ok, sign_binary_upload_url(config, opts)}
  end

  def sign_binary_upload_url(%{endpoint: endpoint} = config, opts) do
    bucket = Keyword.fetch!(opts, :bucket)
    key = Keyword.fetch!(opts, :key)
    request_datetime = Keyword.get(opts, :request_datetime, DateTime.utc_now())
    link_expiry = Keyword.get(opts, :link_expiry, 3_600)
    credential = credential(config, request_datetime)

    uri =
      endpoint
      |> URI.parse()
      |> URI.merge("#{bucket}/#{key}")

    headers_to_sign = %{"Host" => remove_default_port(uri), "Cache-Control" => "max-age=31536000"}

    query =
      %{
        "X-Amz-Algorithm" => @sign_v4_algo,
        "X-Amz-Credential" => credential,
        "X-Amz-Date" => iso8601_datetime(request_datetime),
        "X-Amz-Expires" => to_string(link_expiry),
        "X-Amz-SignedHeaders" => get_signed_headers(headers_to_sign)
      }
      |> URI.encode_query()

    new_uri = Map.put(uri, :query, query)

    string_to_sign =
      string_to_sign(
        config,
        get_canonical_rquest(:put, new_uri, headers_to_sign),
        request_datetime
      )

    signature =
      signing_key(config, request_datetime)
      |> hmac(string_to_sign)
      |> hex_digest()

    %{signed: "#{URI.to_string(new_uri)}&X-Amz-Signature=#{signature}", url: URI.to_string(uri)}
  end

  defp credential(%{} = config, %DateTime{} = requested_at) do
    "#{config.access_key_id}/#{short_date(requested_at)}/#{config.region}/s3/aws4_request"
  end

  defp short_date(%DateTime{} = datetime) do
    datetime
    |> iso8601_date()
    |> String.slice(0..7)
  end

  defp remove_default_port(%URI{host: host, port: port}) when port in [80, 443],
    do: to_string(host)

  defp remove_default_port(%URI{host: host, port: port}),
    do: "#{host}:#{port}"

  defp get_signed_headers(headers) do
    headers
    |> Map.keys()
    |> Enum.map(&String.downcase/1)
    |> Enum.sort()
    |> Enum.join(";")
  end

  defp get_canonical_rquest(method, uri, headers) do
    [
      method |> Atom.to_string() |> String.upcase(),
      uri.path,
      uri.query
    ]
    |> Kernel.++(
      Enum.sort(headers)
      |> Enum.map(fn {k, v} ->
        "#{String.downcase(k)}:#{to_string(v) |> String.trim()}"
      end)
    )
    |> Kernel.++(["", get_signed_headers(headers), @unsigned_payload])
    |> Enum.join("\n")
  end

  defp signing_key(client, request_datetime) do
    "AWS4#{client.secret_access_key}"
    |> hmac(iso8601_date(request_datetime))
    |> hmac(client.region)
    |> hmac("s3")
    |> hmac("aws4_request")
  end

  defp string_to_sign(client, canonical_request, request_datetime) do
    [
      @sign_v4_algo,
      iso8601_datetime(request_datetime),
      get_scope(client, request_datetime),
      canonical_request
      |> sha256()
      |> hex_digest()
    ]
    |> Enum.join("\n")
  end

  defp get_scope(client, request_datetime) do
    [
      iso8601_date(request_datetime),
      client.region,
      "s3",
      "aws4_request"
    ]
    |> Enum.join("/")
  end

  defp iso8601_datetime(date), do: %{date | microsecond: {0, 0}} |> DateTime.to_iso8601(:basic)
  defp iso8601_date(datetime), do: datetime |> DateTime.to_date() |> Date.to_iso8601(:basic)
  defp hmac(key, data), do: :crypto.mac(:hmac, :sha256, key, data)
  defp sha256(data), do: :crypto.hash(:sha256, data)
  defp hex_digest(data), do: Base.encode16(data, case: :lower)
end
