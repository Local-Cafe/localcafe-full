defmodule LocalCafeWeb.OrderHTML do
  use LocalCafeWeb, :html

  embed_templates "order_html/*"

  @doc """
  Formats a price in cents to a dollar string.

  ## Examples

      iex> format_price(1250)
      "$12.50"

      iex> format_price(500)
      "$5.00"
  """
  def format_price(nil), do: "$0.00"

  def format_price(cents) when is_integer(cents) do
    "$#{:erlang.float_to_binary(cents / 100, decimals: 2)}"
  end

  @doc """
  Returns a human-readable status label.

  ## Examples

      iex> format_status("pending")
      "Pending"

      iex> format_status("paid")
      "Paid"
  """
  def format_status(status) do
    status
    |> String.capitalize()
  end

  @doc """
  Returns a CSS class for the order status badge.

  ## Examples

      iex> status_class("pending")
      "status-pending"

      iex> status_class("completed")
      "status-completed"
  """
  def status_class(status) do
    "status-#{status}"
  end

  @doc """
  Checks if an order can be cancelled.

  Users can only cancel pending orders.
  """
  def can_cancel?(order) do
    order.status == "pending"
  end

  @doc """
  Formats a date/time for display.

  ## Examples

      iex> format_datetime(~U[2024-03-15 14:30:00Z])
      "Mar 15, 2024 at 2:30 PM"
  """
  def format_datetime(nil), do: "N/A"

  def format_datetime(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y at %I:%M %p")
  end

  @doc """
  Renders an order card for the orders list.

  ## Examples

      <.order_card order={@order} />
  """
  attr :order, :map, required: true

  def order_card(assigns) do
    ~H"""
    <article class="order-card">
      <div class="order-card-header">
        <h3 class="order-number"><a href={~p"/my-orders/#{@order}"}>{@order.order_number}</a></h3>
        <span class={"order-status " <> status_class(@order.status)}>
          {format_status(@order.status)}
        </span>
      </div>
      <div class="order-card-body">
        <p class="order-date">
          Placed on {format_datetime(@order.inserted_at)}
        </p>
        <p class="order-total">
          Total: {format_price(@order.subtotal)}
        </p>
        <p :if={@order.line_items} class="order-items">
          {length(@order.line_items)} {if length(@order.line_items) == 1, do: "item", else: "items"}
        </p>
      </div>
      <div class="order-card-footer">
        <.button href={~p"/my-orders/#{@order}"} variant="secondary">View Details</.button>
      </div>
    </article>
    """
  end

  @doc """
  Renders an order line item.

  ## Examples

      <.line_item item={@item} />
  """
  attr :item, :map, required: true

  def line_item(assigns) do
    ~H"""
    <div class="line-item">
      <div class="line-item-header">
        <h4 class="line-item-title">{@item.item_title}</h4>
        <span class="line-item-subtotal">{format_price(@item.subtotal)}</span>
      </div>
      <div class="line-item-body">
        <p :if={@item.item_description} class="line-item-description">{@item.item_description}</p>
        <div class="line-item-details">
          <p class="line-item-price">
            <span class="label">Base price:</span>
            <span :if={@item.base_price_label} class="price-label">{@item.base_price_label} -</span>
            {format_price(@item.base_price_amount)}
          </p>
          <div
            :if={@item.selected_variants && length(@item.selected_variants) > 0}
            class="line-item-variants"
          >
            <p class="label">Options:</p>
            <ul class="variant-list">
              <li :for={variant <- @item.selected_variants} class="variant-item">
                {variant.name}
                <span :if={variant.price > 0} class="variant-price">
                  +{format_price(variant.price)}
                </span>
                <span :if={variant.price == 0} class="variant-price-free">
                  (free)
                </span>
              </li>
            </ul>
          </div>
          <p :if={@item.customer_note} class="line-item-note">
            <span class="label">Note:</span> {@item.customer_note}
          </p>
        </div>
      </div>
    </div>
    """
  end
end
