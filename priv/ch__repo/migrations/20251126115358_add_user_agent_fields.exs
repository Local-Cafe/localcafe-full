defmodule LocalCafe.CH_Repo.Migrations.AddUserAgentFields do
  use Ecto.Migration

  def up do
    # Recreate with MergeTree engine and new columns
    execute("""
    CREATE TABLE analytics (
      path String,
      agent String,
      ip String,
      referer String,
      country String,
      session_id String,
      inserted_at DateTime,
      browser String,
      os String,
      device String,
      bot String
    ) ENGINE = MergeTree()
    ORDER BY inserted_at
    """)
  end

  def down do
    execute("DROP TABLE IF EXISTS analytics")
  end
end
