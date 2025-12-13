defmodule LocalCafeWeb.AnalyticsChannel do
  use LocalCafeWeb, :channel

  @impl true
  def join("analytics:dashboard", _payload, socket) do
    # Only allow admins to join
    if authorized?(socket) do
      send(self(), :after_join)
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    # Send initial state when client connects
    push(socket, "initial_state", %{
      last_minute_count: LocalCafe.AnalyticsTracker.get_last_minute_count(),
      last_30_minutes_count: LocalCafe.AnalyticsTracker.get_last_30_minutes_count(),
      last_hour_count: LocalCafe.AnalyticsTracker.get_last_hour_count(),
      last_6_hours_count: LocalCafe.AnalyticsTracker.get_last_6_hours_count(),
      last_12_hours_count: LocalCafe.AnalyticsTracker.get_last_12_hours_count(),
      last_24_hours_count: LocalCafe.AnalyticsTracker.get_last_24_hours_count(),
      activity_buffer: LocalCafe.AnalyticsTracker.get_activity_buffer(50),
      top_pages: LocalCafe.AnalyticsTracker.get_top_pages(10),
      geographic: LocalCafe.AnalyticsTracker.get_geographic_distribution(10),
      top_referrers: LocalCafe.AnalyticsTracker.get_top_referrers(10),
      bot_counts: LocalCafe.AnalyticsTracker.get_bot_counts(10),
      os_counts: LocalCafe.AnalyticsTracker.get_os_counts(10),
      browser_counts: LocalCafe.AnalyticsTracker.get_browser_counts(10)
    })

    # Send initial hourly traffic (from ClickHouse)
    push(socket, "hourly_traffic_update", %{
      hourly_traffic: LocalCafe.AnalyticsTracker.get_hourly_traffic()
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_visit, payload}, socket) do
    # Broadcast new visit to connected dashboard
    push(socket, "new_visit", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:stats_update, payload}, socket) do
    # Broadcast updated stats to connected dashboard
    push(socket, "stats_update", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:hourly_traffic_update, payload}, socket) do
    # Broadcast hourly traffic update (from ClickHouse)
    push(socket, "hourly_traffic_update", payload)
    {:noreply, socket}
  end

  @impl true
  def handle_in("get_metrics", _payload, socket) do
    # Return current metrics when requested
    metrics = %{
      last_minute_count: LocalCafe.AnalyticsTracker.get_last_minute_count(),
      last_30_minutes_count: LocalCafe.AnalyticsTracker.get_last_30_minutes_count(),
      last_hour_count: LocalCafe.AnalyticsTracker.get_last_hour_count(),
      last_6_hours_count: LocalCafe.AnalyticsTracker.get_last_6_hours_count(),
      last_12_hours_count: LocalCafe.AnalyticsTracker.get_last_12_hours_count(),
      last_24_hours_count: LocalCafe.AnalyticsTracker.get_last_24_hours_count(),
      activity_buffer: LocalCafe.AnalyticsTracker.get_activity_buffer(50),
      top_pages: LocalCafe.AnalyticsTracker.get_top_pages(10),
      geographic: LocalCafe.AnalyticsTracker.get_geographic_distribution(10),
      top_referrers: LocalCafe.AnalyticsTracker.get_top_referrers(10),
      bot_counts: LocalCafe.AnalyticsTracker.get_bot_counts(10),
      os_counts: LocalCafe.AnalyticsTracker.get_os_counts(10),
      browser_counts: LocalCafe.AnalyticsTracker.get_browser_counts(10)
    }

    {:reply, {:ok, metrics}, socket}
  end

  # Verify the user is an admin
  defp authorized?(socket) do
    case socket.assigns[:current_user] do
      nil -> false
      user -> user.admin
    end
  end
end
