defmodule LocalCafeWeb.PresignedUrlController do
  use LocalCafeWeb, :controller

  @doc """
  Generates a presigned URL for direct client-side uploads to S3/MinIO.

  Expects JSON payload with:
  - `key`: The S3 object key (filename/path)

  Returns:
  - `signed_url`: The presigned URL for PUT requests
  - `public_url`: The public URL where the file will be accessible after upload
  """
  def generate(conn, %{"key" => key}) when is_binary(key) and key != "" do
    s3_config = Application.get_env(:local_cafe, :s3)

    config = %{
      endpoint: s3_config[:endpoint],
      access_key_id: s3_config[:access_key_id],
      secret_access_key: s3_config[:secret_access_key],
      region: s3_config[:region]
    }

    opts = [
      bucket: s3_config[:bucket],
      key: key,
      # 1 hour
      link_expiry: 3_600
    ]

    {:ok, %{signed: signed_url, url: public_url}} =
      SimpleMinioUpload.sign_binary_upload(config, opts)

    json(conn, %{
      signed_url: signed_url,
      public_url: public_url,
      key: key,
      expires_in: 3600
    })
  end

  def generate(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing required parameter: key"})
  end
end
