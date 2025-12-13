defmodule LocalCafeWeb.PresignedUrlControllerTest do
  use LocalCafeWeb.ConnCase, async: true

  import LocalCafe.AccountsFixtures

  describe "POST /api/presigned-url" do
    setup %{conn: conn} do
      %{conn: conn, user: user_fixture()}
    end

    test "requires admin authentication", %{conn: conn, user: user} do
      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/api/presigned-url", %{key: "test.jpg"})

      assert json_response(conn, 403)["error"] =~ "administrator"
    end

    test "returns 400 when key is missing", %{conn: conn} do
      admin = admin_user_fixture()

      conn =
        conn
        |> log_in_user(admin)
        |> post(~p"/api/presigned-url", %{})

      assert json_response(conn, 400)["error"] =~ "Missing required parameter"
    end

    test "generates presigned URL for admin user", %{conn: conn} do
      admin = admin_user_fixture()
      test_key = "uploads/test-image-#{System.unique_integer([:positive])}.jpg"

      conn =
        conn
        |> log_in_user(admin)
        |> post(~p"/api/presigned-url", %{key: test_key})

      assert %{
               "signed_url" => signed_url,
               "public_url" => public_url,
               "key" => ^test_key,
               "expires_in" => 3600
             } = json_response(conn, 200)

      # Verify the signed URL contains expected S3 signature parameters
      assert signed_url =~ "X-Amz-Algorithm="
      assert signed_url =~ "X-Amz-Credential="
      assert signed_url =~ "X-Amz-Signature="
      assert signed_url =~ test_key

      # Verify public URL is the base URL without signature
      assert public_url =~ test_key
      refute public_url =~ "X-Amz-Signature"
    end
  end
end
