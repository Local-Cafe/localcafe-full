# Generate VAPID keys for Web Push notifications
# Run with: mix run generate_vapid_keys.exs

keys = :crypto.generate_key(:ecdh, :prime256v1)
{public_key, private_key} = keys

public_key_base64 = Base.url_encode64(public_key, padding: false)
private_key_base64 = Base.url_encode64(private_key, padding: false)

IO.puts("\n==============================================")
IO.puts("VAPID Keys Generated Successfully!")
IO.puts("==============================================\n")
IO.puts("Add these to your .env file:\n")
IO.puts("export VAPID_PUBLIC_KEY=\"#{public_key_base64}\"")
IO.puts("export VAPID_PRIVATE_KEY=\"#{private_key_base64}\"")
IO.puts("\n==============================================\n")
