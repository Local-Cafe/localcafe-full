defmodule LocalCafe.UserAgentParser do
  @moduledoc """
  Parses user agent strings using UAInspector to extract browser, OS, device, and bot information.
  """

  @doc """
  Parses a user agent string and returns a map with browser, os, device, and bot information.

  Returns:
    %{
      browser: "Firefox 145.0" | "Unknown",
      os: "Linux" | "Unknown",
      device: "Desktop" | "Mobile",
      bot: "MJ12 Bot" | false
    }
  """
  def parse(agent_string) when agent_string == "" or is_nil(agent_string) do
    %{
      browser: "Unknown",
      os: "Unknown",
      device: "Unknown",
      bot: false
    }
  end

  def parse(agent_string) do
    case UAInspector.parse(agent_string) do
      # Bot detected - Result.Bot struct
      %UAInspector.Result.Bot{name: bot_name} ->
        %{
          browser: bot_name,
          os: "Bot",
          device: "Bot",
          bot: bot_name
        }

      # Regular browser - Result struct with client/os/device
      %UAInspector.Result{} = result ->
        # Get browser info
        browser =
          case result.client do
            %{name: name, version: version} when not is_nil(version) ->
              "#{name} #{version}"

            %{name: name} ->
              name

            _ ->
              "Unknown"
          end

        # Get OS info
        os =
          case result.os do
            %{name: name, version: version}
            when not is_nil(version) and version != :unknown and version != "" ->
              "#{name} #{version}"

            %{name: name} ->
              name

            _ ->
              "Unknown"
          end

        # Get device info
        device =
          case result.device do
            %{type: type, brand: brand, model: model}
            when not is_nil(brand) and not is_nil(model) and
                   brand != "" and model != "" and
                   brand != :unknown and model != :unknown and
                   brand != "unknown" and model != "unknown" ->
              # Only show brand/model if they're meaningful
              "#{String.capitalize(type)} - #{brand} #{model}"

            %{type: type} when not is_nil(type) and type != "" ->
              # Just capitalize the type (mobile, tablet, desktop, etc)
              String.capitalize(type)

            _ ->
              "Desktop"
          end

        %{
          browser: browser,
          os: os,
          device: device,
          bot: false
        }

      _ ->
        %{
          browser: "Unknown",
          os: "Unknown",
          device: "Unknown",
          bot: false
        }
    end
  end
end
