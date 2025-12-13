defmodule LocalCafeWeb.MenuItemHTML do
  use LocalCafeWeb, :html

  embed_templates "menu_item_html/*"

  @doc """
  Renders a menu item card.
  """
  attr :menu_item, :map, required: true
  attr :all_locations, :list, default: []
  attr :use_full_image, :boolean, default: false

  def menu_item_card(assigns) do
    # Get primary image or first image if available
    primary_image =
      if assigns.menu_item.images && length(assigns.menu_item.images) > 0 do
        Enum.find(assigns.menu_item.images, & &1.is_primary) ||
          List.first(assigns.menu_item.images)
      else
        nil
      end

    image_url =
      if primary_image do
        if assigns.use_full_image, do: primary_image.full_url, else: primary_image.thumb_url
      else
        nil
      end

    assigns =
      assigns
      |> assign(:primary_image, primary_image)
      |> assign(:image_url, image_url)

    ~H"""
    <div class="menu-item-card">
      <span :if={!@menu_item.available} class="menu-item-unavailable-badge">Unavailable</span>
      <a :if={@primary_image} href={~p"/menu/#{@menu_item}"} class="menu-item-image-wrapper">
        <img
          class="menu-item-image"
          src={@image_url}
          alt={@menu_item.title}
        />
      </a>
      <div class="menu-item-content">
        <a href={~p"/menu/#{@menu_item}"} class="menu-item-title-link">
          <h3 class="menu-item-title">
            {@menu_item.title}
          </h3>
        </a>
        <p class="menu-item-description">{@menu_item.description}</p>
        <div class="menu-item-footer">
          <div class="menu-item-price">
            {format_price_range(@menu_item.prices)}
          </div>
          <div class="menu-item-meta">
            <div :if={@menu_item.tags != []} class="menu-item-tags">
              <%= for tag <- @menu_item.tags do %>
                <a href={"/?tag=#{tag.name}#menu"} class="tag">
                  {tag.name}
                </a>
              <% end %>
            </div>
            <div
              :if={@menu_item.locations && @menu_item.locations != [] && length(@all_locations) > 1}
              class="menu-item-locations"
            >
              <%= for location <- @menu_item.locations do %>
                <span class="location-label">
                  {location.name}
                </span>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp format_price_range([]), do: ""

  defp format_price_range([%{amount: amount}]) do
    "$#{:erlang.float_to_binary(amount / 100, decimals: 2)}"
  end

  defp format_price_range(prices) when is_list(prices) do
    amounts = Enum.map(prices, & &1.amount)
    min = Enum.min(amounts)
    max = Enum.max(amounts)

    if min == max do
      "$#{:erlang.float_to_binary(min / 100, decimals: 2)}"
    else
      "$#{:erlang.float_to_binary(min / 100, decimals: 2)} - $#{:erlang.float_to_binary(max / 100, decimals: 2)}"
    end
  end
end
