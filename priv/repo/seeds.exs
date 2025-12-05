# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     LocalCafe.Repo.insert!(%LocalCafe.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

# Skip seeding in test environment
if Mix.env() == :test do
  IO.puts("Skipping seed in test environment")
  System.halt(0)
end

alias LocalCafe.Repo
alias LocalCafe.Accounts.User
alias LocalCafe.Accounts.Scope
alias LocalCafe.Posts.Post

# Create admin user
IO.puts("Creating admin user...")

admin =
  %User{}
  |> User.email_changeset(%{email: "hello@localcafe.org"})
  |> User.password_changeset(%{password: "asdfasdfasdfasdf"})
  |> Ecto.Changeset.put_change(:admin, true)
  |> Ecto.Changeset.put_change(:confirmed_at, DateTime.utc_now(:second))
  |> Repo.insert!()

IO.puts("✓ Admin user created: #{admin.email}")

admin_scope = %Scope{user: admin}
