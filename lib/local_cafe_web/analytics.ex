defmodule LocalCafeWeb.Analytics do
  import Plug.Conn

  def write_analytics(conn, _opts) do
    # Skip analytics tracking for admin users
    if is_admin?(conn) do
      conn
    else
      {"user-agent", agent} =
        conn.req_headers |> List.keyfind("user-agent", 0) || {"user-agent", ""}

      {"cf-connecting-ip", ip} =
        conn.req_headers |> List.keyfind("cf-connecting-ip", 0) || {"cf-connecting-ip", ""}

      {"cf-ipcountry", country} =
        conn.req_headers |> List.keyfind("cf-ipcountry", 0) || {"cf-ipcountry", ""}

      {"referer", referer} = conn.req_headers |> List.keyfind("referer", 0) || {"referer", ""}

      # Get or create session ID for tracking unique visitors
      {conn, session_id} = ensure_session_id(conn)

      Task.start(fn ->
        # Parse user agent once
        parsed_agent = LocalCafe.UserAgentParser.parse(agent)

        data = %{
          path: conn.request_path,
          agent: agent,
          ip: ip,
          country: country,
          referer: referer,
          session_id: session_id,
          inserted_at: NaiveDateTime.utc_now(:second),
          browser: parsed_agent.browser,
          os: parsed_agent.os,
          device: parsed_agent.device,
          bot: if(parsed_agent.bot, do: parsed_agent.bot, else: "")
        }

        # Insert into ClickHouse for long-term storage
        LocalCafe.CH_Repo.insert_all(LocalCafe.Anayltics, [data])

        # Track in real-time tracker for dashboard
        LocalCafe.AnalyticsTracker.track_visit(data)
      end)

      conn
    end
  end

  defp is_admin?(conn) do
    case conn.assigns[:current_scope] do
      %{user: %{admin: true}} -> true
      _ -> false
    end
  end

  defp ensure_session_id(conn) do
    case get_session(conn, :analytics_session_id) do
      nil ->
        # Generate new session ID
        session_id = generate_session_id()
        conn = put_session(conn, :analytics_session_id, session_id)
        {conn, session_id}

      session_id ->
        {conn, session_id}
    end
  end

  defp generate_session_id do
    # Generate a random session ID
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end
end
