defmodule LocalCafe.AnalyticsTracker do
  @moduledoc """
  GenServer that tracks real-time analytics data in memory.

  Maintains:
  - Recent visitors (last 100)
  - Online users (active in last 5 minutes)
  - Page view counts
  - Geographic distribution
  """
  use GenServer
  alias Phoenix.PubSub

  # Time windows
  @last_minute_ms 60 * 1000
  @last_30_minutes_ms 30 * 60 * 1000
  @last_hour_ms 60 * 60 * 1000
  @last_6_hours_ms 6 * 60 * 60 * 1000
  @last_12_hours_ms 12 * 60 * 60 * 1000
  @last_24_hours_ms 24 * 60 * 60 * 1000
  # Keep last 100 visitors
  @max_recent_visitors 100

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Record a new visit event"
  def track_visit(visit_data) do
    GenServer.cast(__MODULE__, {:track_visit, visit_data})
  end

  @doc "Get count of visits in the last minute"
  def get_last_minute_count do
    GenServer.call(__MODULE__, :get_last_minute_count)
  end

  @doc "Get count of visits in the last 30 minutes"
  def get_last_30_minutes_count do
    GenServer.call(__MODULE__, :get_last_30_minutes_count)
  end

  @doc "Get count of visits in the last hour"
  def get_last_hour_count do
    GenServer.call(__MODULE__, :get_last_hour_count)
  end

  @doc "Get count of visits in the last 6 hours"
  def get_last_6_hours_count do
    GenServer.call(__MODULE__, :get_last_6_hours_count)
  end

  @doc "Get count of visits in the last 12 hours"
  def get_last_12_hours_count do
    GenServer.call(__MODULE__, :get_last_12_hours_count)
  end

  @doc "Get count of visits in the last 24 hours"
  def get_last_24_hours_count do
    GenServer.call(__MODULE__, :get_last_24_hours_count)
  end

  @doc "Get recent visitors (up to n)"
  def get_recent_visitors(limit \\ 20) do
    GenServer.call(__MODULE__, {:get_recent_visitors, limit})
  end

  @doc "Get activity buffer for live feed (up to n)"
  def get_activity_buffer(limit \\ 50) do
    GenServer.call(__MODULE__, {:get_activity_buffer, limit})
  end

  @doc "Get all current stats for broadcasting"
  def get_all_stats do
    GenServer.call(__MODULE__, :get_all_stats)
  end

  @doc "Get top pages by visit count (up to n)"
  def get_top_pages(limit \\ 10) do
    GenServer.call(__MODULE__, {:get_top_pages, limit})
  end

  @doc "Get geographic distribution (up to n)"
  def get_geographic_distribution(limit \\ 10) do
    GenServer.call(__MODULE__, {:get_geographic_distribution, limit})
  end

  @doc "Get top external referrers (up to n)"
  def get_top_referrers(limit \\ 10) do
    GenServer.call(__MODULE__, {:get_top_referrers, limit})
  end

  @doc "Get bot counts (up to n)"
  def get_bot_counts(limit \\ 10) do
    GenServer.call(__MODULE__, {:get_bot_counts, limit})
  end

  @doc "Get OS distribution (up to n)"
  def get_os_counts(limit \\ 10) do
    GenServer.call(__MODULE__, {:get_os_counts, limit})
  end

  @doc "Get browser distribution (up to n)"
  def get_browser_counts(limit \\ 10) do
    GenServer.call(__MODULE__, {:get_browser_counts, limit})
  end

  @doc "Get hourly traffic (60 counts, one per minute)"
  def get_hourly_traffic do
    GenServer.call(__MODULE__, :get_hourly_traffic)
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    # Schedule periodic cleanup
    schedule_cleanup()

    # Schedule delayed initialization from ClickHouse (wait for DB to be ready)
    schedule_initial_load()

    # Schedule periodic stats broadcast
    schedule_stats_broadcast()

    # Schedule hourly traffic broadcast (separate from real-time stats)
    schedule_hourly_traffic_broadcast()

    # Start with empty state
    state = empty_state()

    {:ok, state}
  end

  @impl true
  def handle_cast({:track_visit, visit_data}, state) do
    now = System.system_time(:millisecond)

    # Add timestamp if not present
    visit = Map.put_new(visit_data, :timestamp, now)

    # Parse user agent if not already parsed (for backwards compatibility)
    parsed_agent =
      if Map.has_key?(visit_data, :browser) do
        # Already parsed, use the data from ClickHouse/Analytics plug
        %{
          browser: visit_data[:browser] || "Unknown",
          os: visit_data[:os] || "Unknown",
          device: visit_data[:device] || "Unknown",
          bot: if(visit_data[:bot] && visit_data[:bot] != "", do: visit_data[:bot], else: false)
        }
      else
        # Parse user agent (legacy path)
        LocalCafe.UserAgentParser.parse(visit[:agent] || "")
      end

    # Update recent visitors (keep last N)
    recent_visitors =
      [visit | state.recent_visitors]
      |> Enum.take(@max_recent_visitors)

    # Update page counts
    page_counts =
      Map.update(state.page_counts, visit.path, 1, &(&1 + 1))

    # Update geographic distribution
    geographic =
      if visit[:country] && visit.country != "" do
        Map.update(state.geographic, visit.country, 1, &(&1 + 1))
      else
        state.geographic
      end

    # Update referrers (exclude internal/empty referrers)
    referrers =
      if visit[:referer] && visit.referer != "" && is_external_referrer?(visit.referer) do
        Map.update(state.referrers, visit.referer, 1, &(&1 + 1))
      else
        state.referrers
      end

    # Update bot counts
    bot_counts =
      if parsed_agent.bot do
        # Track by bot name
        Map.update(state.bot_counts, parsed_agent.bot, 1, &(&1 + 1))
      else
        state.bot_counts
      end

    # Update OS counts
    os_counts =
      if parsed_agent.os && parsed_agent.os != "Unknown" do
        Map.update(state.os_counts, parsed_agent.os, 1, &(&1 + 1))
      else
        state.os_counts
      end

    # Update browser counts
    browser_counts =
      if parsed_agent.browser && parsed_agent.browser != "Unknown" && !parsed_agent.bot do
        Map.update(state.browser_counts, parsed_agent.browser, 1, &(&1 + 1))
      else
        state.browser_counts
      end

    new_state = %{
      state
      | recent_visitors: recent_visitors,
        page_counts: page_counts,
        geographic: geographic,
        referrers: referrers,
        bot_counts: bot_counts,
        os_counts: os_counts,
        browser_counts: browser_counts
    }

    # Broadcast to analytics channel with enhanced visit data
    PubSub.broadcast(
      LocalCafe.PubSub,
      "analytics:dashboard",
      {:new_visit, format_visit_for_activity_feed(visit)}
    )

    # Also broadcast updated stats
    PubSub.broadcast(
      LocalCafe.PubSub,
      "analytics:dashboard",
      {:stats_update,
       %{
         last_minute_count: get_last_minute_count_from_state(new_state),
         last_30_minutes_count: get_last_30_minutes_count_from_state(new_state),
         last_hour_count: get_last_hour_count_from_state(new_state),
         last_6_hours_count: get_last_6_hours_count_from_state(new_state),
         last_12_hours_count: get_last_12_hours_count_from_state(new_state),
         last_24_hours_count: get_last_24_hours_count_from_state(new_state),
         top_pages: get_top_pages_from_state(new_state, 10),
         geographic: get_geographic_from_state(new_state, 10),
         top_referrers: get_top_referrers_from_state(new_state, 10),
         bot_counts: get_bot_counts_from_state(new_state, 10),
         os_counts: get_os_counts_from_state(new_state, 10),
         browser_counts: get_browser_counts_from_state(new_state, 10)
       }}
    )

    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_last_minute_count, _from, state) do
    {:reply, count_unique_sessions_in_window(state, @last_minute_ms), state}
  end

  @impl true
  def handle_call(:get_last_30_minutes_count, _from, state) do
    {:reply, count_unique_sessions_in_window(state, @last_30_minutes_ms), state}
  end

  @impl true
  def handle_call(:get_last_hour_count, _from, state) do
    {:reply, count_unique_sessions_in_window(state, @last_hour_ms), state}
  end

  @impl true
  def handle_call(:get_last_6_hours_count, _from, state) do
    {:reply, count_unique_sessions_in_window(state, @last_6_hours_ms), state}
  end

  @impl true
  def handle_call(:get_last_12_hours_count, _from, state) do
    {:reply, count_unique_sessions_in_window(state, @last_12_hours_ms), state}
  end

  @impl true
  def handle_call(:get_last_24_hours_count, _from, state) do
    {:reply, count_unique_sessions_in_window(state, @last_24_hours_ms), state}
  end

  @impl true
  def handle_call({:get_recent_visitors, limit}, _from, state) do
    visitors =
      state.recent_visitors
      |> Enum.take(limit)
      |> Enum.map(&format_visit_for_response/1)

    {:reply, visitors, state}
  end

  @impl true
  def handle_call({:get_top_pages, limit}, _from, state) do
    top_pages =
      state.page_counts
      |> Enum.sort_by(fn {_path, count} -> count end, :desc)
      |> Enum.take(limit)
      |> Enum.map(fn {path, count} ->
        %{path: path, count: count}
      end)

    {:reply, top_pages, state}
  end

  @impl true
  def handle_call({:get_geographic_distribution, limit}, _from, state) do
    geographic =
      state.geographic
      |> Enum.sort_by(fn {_country, count} -> count end, :desc)
      |> Enum.take(limit)
      |> Enum.map(fn {country, count} ->
        %{country: country, count: count}
      end)

    {:reply, geographic, state}
  end

  @impl true
  def handle_call({:get_top_referrers, limit}, _from, state) do
    referrers =
      state.referrers
      |> Enum.sort_by(fn {_referrer, count} -> count end, :desc)
      |> Enum.take(limit)
      |> Enum.map(fn {referrer, count} ->
        %{referrer: referrer, count: count}
      end)

    {:reply, referrers, state}
  end

  @impl true
  def handle_call({:get_bot_counts, limit}, _from, state) do
    bots =
      state.bot_counts
      |> Enum.sort_by(fn {_bot, count} -> count end, :desc)
      |> Enum.take(limit)
      |> Enum.map(fn {bot, count} ->
        %{name: bot, count: count}
      end)

    {:reply, bots, state}
  end

  @impl true
  def handle_call({:get_os_counts, limit}, _from, state) do
    oses =
      state.os_counts
      |> Enum.sort_by(fn {_os, count} -> count end, :desc)
      |> Enum.take(limit)
      |> Enum.map(fn {os, count} ->
        %{name: os, count: count}
      end)

    {:reply, oses, state}
  end

  @impl true
  def handle_call({:get_browser_counts, limit}, _from, state) do
    browsers =
      state.browser_counts
      |> Enum.sort_by(fn {_browser, count} -> count end, :desc)
      |> Enum.take(limit)
      |> Enum.map(fn {browser, count} ->
        %{name: browser, count: count}
      end)

    {:reply, browsers, state}
  end

  @impl true
  def handle_call({:get_activity_buffer, limit}, _from, state) do
    activities =
      state.recent_visitors
      |> Enum.take(limit)
      |> Enum.map(&format_visit_for_activity_feed/1)

    {:reply, activities, state}
  end

  @impl true
  def handle_call(:get_hourly_traffic, _from, state) do
    hourly_traffic = get_hourly_traffic_from_state(state)
    {:reply, hourly_traffic, state}
  end

  @impl true
  def handle_call(:get_all_stats, _from, state) do
    stats = %{
      last_minute_count: get_last_minute_count_from_state(state),
      last_30_minutes_count: get_last_30_minutes_count_from_state(state),
      last_hour_count: get_last_hour_count_from_state(state),
      last_6_hours_count: get_last_6_hours_count_from_state(state),
      last_12_hours_count: get_last_12_hours_count_from_state(state),
      last_24_hours_count: get_last_24_hours_count_from_state(state),
      recent_visitors: get_recent_visitors_from_state(state, 20),
      top_pages: get_top_pages_from_state(state, 10),
      geographic: get_geographic_from_state(state, 10),
      top_referrers: get_top_referrers_from_state(state, 10),
      activity_buffer: get_activity_buffer_from_state(state, 50),
      bot_counts: get_bot_counts_from_state(state, 10),
      os_counts: get_os_counts_from_state(state, 10),
      browser_counts: get_browser_counts_from_state(state, 10)
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.system_time(:millisecond)
    cutoff = now - @last_hour_ms

    # Remove visits older than 1 hour
    recent_visitors =
      Enum.filter(state.recent_visitors, fn v ->
        v.timestamp >= cutoff
      end)

    # Schedule next cleanup
    schedule_cleanup()

    {:noreply, %{state | recent_visitors: recent_visitors}}
  end

  @impl true
  def handle_info(:broadcast_stats, state) do
    # Broadcast updated stats to all connected dashboards
    PubSub.broadcast(
      LocalCafe.PubSub,
      "analytics:dashboard",
      {:stats_update,
       %{
         last_minute_count: get_last_minute_count_from_state(state),
         last_30_minutes_count: get_last_30_minutes_count_from_state(state),
         last_hour_count: get_last_hour_count_from_state(state),
         last_6_hours_count: get_last_6_hours_count_from_state(state),
         last_12_hours_count: get_last_12_hours_count_from_state(state),
         last_24_hours_count: get_last_24_hours_count_from_state(state),
         top_pages: get_top_pages_from_state(state, 10),
         geographic: get_geographic_from_state(state, 10),
         top_referrers: get_top_referrers_from_state(state, 10),
         bot_counts: get_bot_counts_from_state(state, 10),
         os_counts: get_os_counts_from_state(state, 10),
         browser_counts: get_browser_counts_from_state(state, 10)
       }}
    )

    # Schedule next broadcast
    schedule_stats_broadcast()

    {:noreply, state}
  end

  @impl true
  def handle_info(:broadcast_hourly_traffic, state) do
    # Query ClickHouse for hourly traffic counts
    hourly_traffic = query_hourly_traffic_from_clickhouse()

    # Broadcast to analytics dashboard
    PubSub.broadcast(
      LocalCafe.PubSub,
      "analytics:dashboard",
      {:hourly_traffic_update, %{hourly_traffic: hourly_traffic}}
    )

    # Schedule next broadcast
    schedule_hourly_traffic_broadcast()

    {:noreply, state}
  end

  @impl true
  def handle_info({:load_initial_data, retry_count}, state) do
    require Logger

    # Only load if we still have empty or nearly empty state
    if length(state.recent_visitors) < 10 do
      loaded_state = load_initial_state_from_clickhouse()

      case loaded_state do
        %{recent_visitors: []} when retry_count < 2 ->
          # Failed to load and we have retries left - try again in 5 seconds
          Logger.info(
            "ClickHouse not ready, will retry in 5 seconds (attempt #{retry_count + 1}/2)"
          )

          Process.send_after(self(), {:load_initial_data, retry_count + 1}, 5_000)
          {:noreply, state}

        %{recent_visitors: []} ->
          # Failed after retries - give up
          Logger.info("ClickHouse not ready after retries, continuing with empty state")
          {:noreply, state}

        loaded_state ->
          # Successfully loaded data
          {:noreply, loaded_state}
      end
    else
      # Already have data (from live visits), skip loading
      {:noreply, state}
    end
  end

  ## Private Functions

  defp load_initial_state_from_clickhouse do
    require Logger

    try do
      # Query last hour of data from ClickHouse
      one_hour_ago =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(-3600, :second)
        |> NaiveDateTime.truncate(:second)

      now_ms = System.system_time(:millisecond)

      # Format datetime for ClickHouse (YYYY-MM-DD HH:MM:SS without microseconds)
      datetime_str = NaiveDateTime.to_string(one_hour_ago)

      query = """
      SELECT
        path,
        agent,
        ip,
        referer,
        country,
        session_id,
        inserted_at,
        browser,
        os,
        device,
        bot
      FROM analytics
      WHERE inserted_at >= '#{datetime_str}'
      ORDER BY inserted_at DESC
      """

      case LocalCafe.CH_Repo.query(query) do
        {:ok, result} ->
          # Transform rows into visit records
          all_visits =
            result.rows
            |> Enum.map(fn row ->
              [
                path,
                agent,
                ip,
                referer,
                country,
                session_id,
                inserted_at,
                browser,
                os,
                device,
                bot
              ] =
                row

              # Convert NaiveDateTime to millisecond timestamp
              timestamp =
                case inserted_at do
                  %NaiveDateTime{} = dt ->
                    DateTime.from_naive!(dt, "Etc/UTC")
                    |> DateTime.to_unix(:millisecond)

                  _ ->
                    now_ms
                end

              %{
                path: path || "",
                agent: agent || "",
                ip: ip || "",
                referer: referer || "",
                country: country || "",
                session_id: session_id || "",
                timestamp: timestamp,
                browser: browser || "Unknown",
                os: os || "Unknown",
                device: device || "Unknown",
                bot: if(bot && bot != "", do: bot, else: false)
              }
            end)

          # Build aggregated maps from ALL visits in the last hour for accurate counts
          page_counts =
            Enum.reduce(all_visits, %{}, fn visit, acc ->
              Map.update(acc, visit.path, 1, &(&1 + 1))
            end)

          geographic =
            Enum.reduce(all_visits, %{}, fn visit, acc ->
              if visit.country != "" do
                Map.update(acc, visit.country, 1, &(&1 + 1))
              else
                acc
              end
            end)

          referrers =
            Enum.reduce(all_visits, %{}, fn visit, acc ->
              if visit.referer != "" && is_external_referrer?(visit.referer) do
                Map.update(acc, visit.referer, 1, &(&1 + 1))
              else
                acc
              end
            end)

          # Build bot/OS/browser counts from already-parsed data
          {bot_counts, os_counts, browser_counts} =
            Enum.reduce(all_visits, {%{}, %{}, %{}}, fn visit, {bots, oses, browsers} ->
              new_bots =
                if visit.bot && visit.bot != false do
                  Map.update(bots, visit.bot, 1, &(&1 + 1))
                else
                  bots
                end

              new_oses =
                if visit.os && visit.os != "Unknown" do
                  Map.update(oses, visit.os, 1, &(&1 + 1))
                else
                  oses
                end

              new_browsers =
                if visit.browser && visit.browser != "Unknown" &&
                     (!visit.bot || visit.bot == false) do
                  Map.update(browsers, visit.browser, 1, &(&1 + 1))
                else
                  browsers
                end

              {new_bots, new_oses, new_browsers}
            end)

          # Keep only the most recent 100 visits for the activity feed
          recent_visitors = Enum.take(all_visits, @max_recent_visitors)

          Logger.info(
            "Loaded #{length(all_visits)} visits from ClickHouse (keeping #{length(recent_visitors)} for activity feed)"
          )

          %{
            recent_visitors: recent_visitors,
            page_counts: page_counts,
            geographic: geographic,
            referrers: referrers,
            bot_counts: bot_counts,
            os_counts: os_counts,
            browser_counts: browser_counts
          }

        {:error, reason} ->
          Logger.warning(
            "Failed to load initial analytics state from ClickHouse: #{inspect(reason)}"
          )

          empty_state()
      end
    rescue
      error ->
        Logger.warning("Error loading initial analytics state: #{inspect(error)}")
        empty_state()
    end
  end

  defp empty_state do
    %{
      recent_visitors: [],
      page_counts: %{},
      geographic: %{},
      referrers: %{},
      bot_counts: %{},
      os_counts: %{},
      browser_counts: %{}
    }
  end

  defp schedule_cleanup do
    # Clean up every 5 minutes
    Process.send_after(self(), :cleanup, 5 * 60 * 1000)
  end

  defp schedule_initial_load do
    # Wait 3 seconds for ClickHouse to be ready, then try to load initial data
    Process.send_after(self(), {:load_initial_data, 0}, 3_000)
  end

  defp schedule_stats_broadcast do
    # Broadcast stats every minute
    Process.send_after(self(), :broadcast_stats, 60 * 1000)
  end

  defp schedule_hourly_traffic_broadcast do
    # Broadcast hourly traffic every minute (separate from real-time stats)
    Process.send_after(self(), :broadcast_hourly_traffic, 60 * 1000)
  end

  defp format_visit_for_activity_feed(visit) do
    # Use already-parsed data if available, otherwise parse
    parsed_agent =
      if Map.has_key?(visit, :browser) do
        %{
          browser: visit[:browser] || "Unknown",
          os: visit[:os] || "Unknown",
          device: visit[:device] || "Unknown",
          bot: if(visit[:bot] && visit[:bot] != "", do: visit[:bot], else: false)
        }
      else
        LocalCafe.UserAgentParser.parse(visit[:agent] || "")
      end

    %{
      path: visit.path,
      country: visit[:country] || "Unknown",
      agent: visit[:agent] || "",
      browser: parsed_agent.browser,
      os: parsed_agent.os,
      device: parsed_agent.device,
      bot: parsed_agent.bot,
      ip: visit[:ip] || "Unknown",
      session_id: visit[:session_id] || "Unknown",
      timestamp: visit.timestamp,
      time_ago: time_ago(visit.timestamp)
    }
  end

  defp format_visit_for_response(visit) do
    %{
      path: visit.path,
      country: visit[:country] || "Unknown",
      agent: visit[:agent] || "",
      timestamp: visit.timestamp,
      time_ago: time_ago(visit.timestamp)
    }
  end

  defp time_ago(timestamp) do
    now = System.system_time(:millisecond)
    diff_seconds = div(now - timestamp, 1000)

    cond do
      diff_seconds < 60 -> "#{diff_seconds}s ago"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      true -> "#{div(diff_seconds, 3600)}h ago"
    end
  end

  defp is_external_referrer?(referrer) do
    # Filter out internal referrers (localhost and production domain)
    !String.contains?(referrer, ["localhost", "127.0.0.1", "0.0.0.0"])
  end

  # Helper functions that work on state directly (for efficient broadcasting)
  defp count_unique_sessions_in_window(state, window_ms) do
    now = System.system_time(:millisecond)
    cutoff = now - window_ms

    state.recent_visitors
    |> Enum.filter(fn v -> v.timestamp >= cutoff end)
    |> Enum.map(fn v -> v[:session_id] end)
    |> Enum.filter(& &1)
    |> Enum.uniq()
    |> length()
  end

  defp get_last_minute_count_from_state(state) do
    count_unique_sessions_in_window(state, @last_minute_ms)
  end

  defp get_last_30_minutes_count_from_state(state) do
    count_unique_sessions_in_window(state, @last_30_minutes_ms)
  end

  defp get_last_hour_count_from_state(state) do
    count_unique_sessions_in_window(state, @last_hour_ms)
  end

  defp get_last_6_hours_count_from_state(state) do
    count_unique_sessions_in_window(state, @last_6_hours_ms)
  end

  defp get_last_12_hours_count_from_state(state) do
    count_unique_sessions_in_window(state, @last_12_hours_ms)
  end

  defp get_last_24_hours_count_from_state(state) do
    count_unique_sessions_in_window(state, @last_24_hours_ms)
  end

  defp get_recent_visitors_from_state(state, limit) do
    state.recent_visitors
    |> Enum.take(limit)
    |> Enum.map(&format_visit_for_response/1)
  end

  defp get_top_pages_from_state(state, limit) do
    state.page_counts
    |> Enum.sort_by(fn {_path, count} -> count end, :desc)
    |> Enum.take(limit)
    |> Enum.map(fn {path, count} ->
      %{path: path, count: count}
    end)
  end

  defp get_geographic_from_state(state, limit) do
    state.geographic
    |> Enum.sort_by(fn {_country, count} -> count end, :desc)
    |> Enum.take(limit)
    |> Enum.map(fn {country, count} ->
      %{country: country, count: count}
    end)
  end

  defp get_top_referrers_from_state(state, limit) do
    state.referrers
    |> Enum.sort_by(fn {_referrer, count} -> count end, :desc)
    |> Enum.take(limit)
    |> Enum.map(fn {referrer, count} ->
      %{referrer: referrer, count: count}
    end)
  end

  defp get_activity_buffer_from_state(state, limit) do
    state.recent_visitors
    |> Enum.take(limit)
    |> Enum.map(&format_visit_for_activity_feed/1)
  end

  defp get_bot_counts_from_state(state, limit) do
    state.bot_counts
    |> Enum.sort_by(fn {_bot, count} -> count end, :desc)
    |> Enum.take(limit)
    |> Enum.map(fn {bot, count} ->
      %{name: bot, count: count}
    end)
  end

  defp get_os_counts_from_state(state, limit) do
    state.os_counts
    |> Enum.sort_by(fn {_os, count} -> count end, :desc)
    |> Enum.take(limit)
    |> Enum.map(fn {os, count} ->
      %{name: os, count: count}
    end)
  end

  defp get_browser_counts_from_state(state, limit) do
    state.browser_counts
    |> Enum.sort_by(fn {_browser, count} -> count end, :desc)
    |> Enum.take(limit)
    |> Enum.map(fn {browser, count} ->
      %{name: browser, count: count}
    end)
  end

  defp get_hourly_traffic_from_state(state) do
    now = System.system_time(:millisecond)

    # Create buckets for each minute (0-59)
    buckets =
      state.recent_visitors
      |> Enum.reduce(%{}, fn visit, acc ->
        minutes_ago = div(now - visit.timestamp, 60_000)

        if minutes_ago >= 0 and minutes_ago < 60 do
          session_id = visit[:session_id]

          if session_id do
            bucket_sessions = Map.get(acc, minutes_ago, MapSet.new())
            Map.put(acc, minutes_ago, MapSet.put(bucket_sessions, session_id))
          else
            acc
          end
        else
          acc
        end
      end)

    # Convert to array of counts (0-59 minutes ago)
    0..59
    |> Enum.map(fn i ->
      buckets
      |> Map.get(i, MapSet.new())
      |> MapSet.size()
    end)
  end

  defp query_hourly_traffic_from_clickhouse do
    require Logger

    try do
      now = NaiveDateTime.utc_now()
      one_hour_ago = NaiveDateTime.add(now, -3600, :second) |> NaiveDateTime.truncate(:second)

      # Query ClickHouse for visits in the last hour
      query = """
      SELECT
        session_id,
        inserted_at
      FROM analytics
      WHERE inserted_at >= '#{NaiveDateTime.to_string(one_hour_ago)}'
        AND session_id != ''
      ORDER BY inserted_at DESC
      """

      case LocalCafe.CH_Repo.query(query) do
        {:ok, result} ->
          now_ms = System.system_time(:millisecond)

          # Group by minute and count unique sessions
          buckets =
            result.rows
            |> Enum.reduce(%{}, fn [session_id, inserted_at], acc ->
              timestamp =
                case inserted_at do
                  %NaiveDateTime{} = dt ->
                    DateTime.from_naive!(dt, "Etc/UTC")
                    |> DateTime.to_unix(:millisecond)

                  _ ->
                    now_ms
                end

              minutes_ago = div(now_ms - timestamp, 60_000)

              if minutes_ago >= 0 and minutes_ago < 60 and session_id do
                bucket_sessions = Map.get(acc, minutes_ago, MapSet.new())
                Map.put(acc, minutes_ago, MapSet.put(bucket_sessions, session_id))
              else
                acc
              end
            end)

          # Convert to array of counts (0-59 minutes ago)
          0..59
          |> Enum.map(fn i ->
            buckets
            |> Map.get(i, MapSet.new())
            |> MapSet.size()
          end)

        {:error, reason} ->
          Logger.warning("Failed to query hourly traffic from ClickHouse: #{inspect(reason)}")
          # Return empty array
          List.duplicate(0, 60)
      end
    rescue
      error ->
        Logger.warning("Error querying hourly traffic: #{inspect(error)}")
        # Return empty array
        List.duplicate(0, 60)
    end
  end
end
