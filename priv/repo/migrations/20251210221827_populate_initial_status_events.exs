defmodule LocalCafe.Repo.Migrations.PopulateInitialStatusEvents do
  use Ecto.Migration

  def up do
    execute """
    UPDATE orders
    SET status_events = jsonb_build_array(
      jsonb_build_object(
        'from_status', NULL,
        'to_status', status,
        'changed_by', jsonb_build_object(
          'id', NULL,
          'email', 'system',
          'admin', true
        ),
        'changed_at', inserted_at
      )
    )
    WHERE status_events = '[]'::jsonb
    """
  end

  def down do
    execute "UPDATE orders SET status_events = '[]'::jsonb"
  end
end
