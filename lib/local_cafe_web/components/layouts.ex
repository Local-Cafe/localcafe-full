defmodule LocalCafeWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use LocalCafeWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :current_path, :string,
    required: true,
    doc: "the current request path for determining active nav"

  attr :cart_count, :integer,
    default: 0,
    doc: "the number of items in the cart"

  attr :cart_subtotal, :integer,
    default: 0,
    doc: "the cart subtotal in cents"

  attr :notification_count, :integer,
    default: 0,
    doc: "the number of unread notifications"

  attr :has_blog_posts, :boolean,
    default: false,
    doc: "whether there are any published blog posts"

  slot :inner_block, required: true
  slot :admin_bar
  slot :hero

  def app(assigns) do
    cart_count = Map.get(assigns, :cart_count, 0)
    cart_subtotal = Map.get(assigns, :cart_subtotal, 0)
    notification_count = Map.get(assigns, :notification_count, 0)
    has_blog_posts = Map.get(assigns, :has_blog_posts, false)

    assigns =
      assigns
      |> Map.put(:cart_count, cart_count)
      |> Map.put(:cart_subtotal, cart_subtotal)
      |> Map.put(:notification_count, notification_count)
      |> Map.put(:has_blog_posts, has_blog_posts)

    ~H"""
    <header class="site-header">
      <nav class="site-nav">
        <div class="nav-container">
          <div class="nav-content">
            <div class="nav-left">
              <div class="nav-logo">
                <.link class="nav-link" href={~p"/"}>
                  LOCALCAFE.ORG
                </.link>
              </div>
              <div class="nav-links-desktop">
                <div class="nav-links">
                  <.link href={~p"/#menu"} class={nav_link_class(@current_path, "/#menu")}>
                    Menu
                  </.link>
                  <.link href={~p"/#locations"} class={nav_link_class(@current_path, "/#locations")}>
                    Locations
                  </.link>
                  <%= if @has_blog_posts do %>
                    <.link href={~p"/#posts"} class={nav_link_class(@current_path, "/#posts")}>
                      Blog
                    </.link>
                  <% end %>
                </div>
              </div>
            </div>
            <div class="nav-right">
              <%= if @cart_count > 0 do %>
                <.link href={~p"/cart"} class="nav-cart">
                  <span class="nav-cart-inset"></span>
                  <span class="sr-only">View cart</span>
                  <svg
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    aria-hidden="true"
                    class="nav-icon"
                  >
                    <path
                      d="M2.25 3h1.386c.51 0 .955.343 1.087.835l.383 1.437M7.5 14.25a3 3 0 0 0-3 3h15.75m-12.75-3h11.218c1.121-2.3 2.1-4.684 2.924-7.138a60.114 60.114 0 0 0-16.536-1.84M7.5 14.25 5.106 5.272M6 20.25a.75.75 0 1 1-1.5 0 .75.75 0 0 1 1.5 0Zm12.75 0a.75.75 0 1 1-1.5 0 .75.75 0 0 1 1.5 0Z"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    />
                  </svg>
                  <span class="nav-cart-badge">{@cart_count}</span>
                </.link>
              <% end %>

              <%= if @current_scope do %>
                <.link href={~p"/notifications"} class="nav-notification">
                  <span class="nav-notification-inset"></span>
                  <span class="sr-only">View notifications</span>
                  <svg
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="1.5"
                    aria-hidden="true"
                    class="nav-icon"
                  >
                    <path
                      d="M14.857 17.082a23.848 23.848 0 0 0 5.454-1.31A8.967 8.967 0 0 1 18 9.75V9A6 6 0 0 0 6 9v.75a8.967 8.967 0 0 1-2.312 6.022c1.733.64 3.56 1.085 5.455 1.31m5.714 0a24.255 24.255 0 0 1-5.714 0m5.714 0a3 3 0 1 1-5.714 0"
                      stroke-linecap="round"
                      stroke-linejoin="round"
                    />
                  </svg>
                  <%= if @notification_count > 0 do %>
                    <span class="nav-notification-badge">{@notification_count}</span>
                  <% end %>
                </.link>

                <div class="nav-profile-dropdown" data-dropdown>
                  <button class="nav-profile-button" data-dropdown-button>
                    <span class="nav-profile-inset"></span>
                    <span class="sr-only">Open user menu</span>
                    <span class="nav-profile-avatar">{String.first(@current_scope.user.email)}</span>
                  </button>

                  <div hidden class="nav-dropdown-menu" data-dropdown-menu>
                    <span class="nav-dropdown-item nav-dropdown-item-email">
                      {@current_scope.user.email}
                    </span>
                    <%= if @current_scope.user.admin do %>
                      <.link href={~p"/admin"} class="nav-dropdown-item">
                        Admin Dashboard
                      </.link>
                    <% else %>
                      <.link href={~p"/my-orders"} class="nav-dropdown-item">
                        Orders
                      </.link>
                    <% end %>
                    <.link href={~p"/users/settings"} class="nav-dropdown-item">
                      Settings
                    </.link>
                    <.link href={~p"/users/log-out"} method="delete" class="nav-dropdown-item">
                      Sign out
                    </.link>
                  </div>
                </div>
              <% else %>
                <div class="nav-auth-links">
                  <.link href={~p"/users/log-in"} class="nav-link">
                    Log in
                  </.link>
                </div>
              <% end %>

              <%!-- Mobile menu toggle button --%>
              <button
                command="--toggle"
                commandfor="mobile-menu"
                aria-expanded="false"
                aria-label="Toggle navigation menu"
                class="nav-toggle"
              >
                <svg
                  class="nav-icon nav-icon-menu"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="currentColor"
                  aria-hidden="true"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"
                  />
                </svg>
                <svg
                  class="nav-icon nav-icon-close"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke-width="1.5"
                  stroke="currentColor"
                  aria-hidden="true"
                >
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
          </div>
        </div>

        <div id="mobile-menu" hidden class="nav-mobile-menu">
          <div class="nav-mobile-content">
            <.link href={~p"/#menu"} class={mobile_nav_link_class(@current_path, "/#menu")}>
              Menu
            </.link>
            <.link href={~p"/#locations"} class={mobile_nav_link_class(@current_path, "/#locations")}>
              Locations
            </.link>
            <%= if @has_blog_posts do %>
              <.link href={~p"/#posts"} class={mobile_nav_link_class(@current_path, "/#posts")}>
                Blog
              </.link>
            <% end %>
            <%= if @current_scope do %>
              <%= if @current_scope.user.admin do %>
                <.link href={~p"/admin"} class="nav-mobile-link">
                  Admin Dashboard
                </.link>
              <% else %>
                <.link href={~p"/payments"} class="nav-mobile-link">
                  Payments
                </.link>
              <% end %>
              <.link href={~p"/users/settings"} class="nav-mobile-link">
                Settings
              </.link>
              <.link href={~p"/users/log-out"} method="delete" class="nav-mobile-link">
                Sign out
              </.link>
            <% else %>
              <.link href={~p"/users/log-in"} class="nav-mobile-link">
                Log in
              </.link>
            <% end %>
          </div>
        </div>
      </nav>
      <%= if @current_scope && @current_scope.user && @current_scope.user.admin && @admin_bar != [] do %>
        <div class="admin-bar">
          <div class="admin-bar-container">
            <div class="admin-bar-content">
              <div class="admin-bar-label">
                <svg
                  viewBox="0 0 20 20"
                  fill="currentColor"
                  aria-hidden="true"
                  class="admin-bar-icon"
                >
                  <path
                    fill-rule="evenodd"
                    d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.857-9.809a.75.75 0 00-1.214-.882l-3.483 4.79-1.88-1.88a.75.75 0 10-1.06 1.061l2.5 2.5a.75.75 0 001.137-.089l4-5.5z"
                    clip-rule="evenodd"
                  />
                </svg>
                <span>Admin Mode</span>
              </div>
              <div class="admin-bar-actions">
                {render_slot(@admin_bar)}
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </header>
    {render_slot(@hero)}

    <main>
      {render_slot(@inner_block)}
    </main>

    <footer class="site-footer">
      <%!-- Footer Bottom --%>
      <div class="footer-container">
        <div class="footer-content">
          <div class="footer-social">
            <a href="https://bsky.app/profile/localcafe.org" class="footer-social-link">
              <span class="sr-only">Bluesky</span>
              <svg
                role="img"
                viewBox="0 0 24 24"
                xmlns="http://www.w3.org/2000/svg"
                class="footer-icon"
              >
                <title>Bluesky</title>
                <path d="M5.202 2.857C7.954 4.922 10.913 9.11 12 11.358c1.087-2.247 4.046-6.436 6.798-8.501C20.783 1.366 24 .213 24 3.883c0 .732-.42 6.156-.667 7.037-.856 3.061-3.978 3.842-6.755 3.37 4.854.826 6.089 3.562 3.422 6.299-5.065 5.196-7.28-1.304-7.847-2.97-.104-.305-.152-.448-.153-.327 0-.121-.05.022-.153.327-.568 1.666-2.782 8.166-7.847 2.97-2.667-2.737-1.432-5.473 3.422-6.3-2.777.473-5.899-.308-6.755-3.369C.42 10.04 0 4.615 0 3.883c0-3.67 3.217-2.517 5.202-1.026" />
              </svg>
            </a>
            <a href="https://github.com/Local-Cafe/localcafe-full" class="footer-social-link">
              <span class="sr-only">Github</span>
              <svg
                role="img"
                viewBox="0 0 24 24"
                xmlns="http://www.w3.org/2000/svg"
                class="footer-icon"
              >
                <title>GitHub</title>
                <path d="M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12" />
              </svg>
            </a>
          </div>
          <nav class="footer-nav">
            <.link href={~p"/"} class="footer-nav-link">Foobar</.link>
          </nav>
          <p class="footer-copyright">
            &copy; {DateTime.utc_now().year} LocalCafe.org ~ All rights reserved.
          </p>
        </div>
      </div>
    </footer>
    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />
    </div>
    """
  end

  # Helper function to determine if a nav link is active
  defp nav_link_class(current_path, link_path) do
    base_class = "nav-link"

    if String.starts_with?(current_path, link_path) do
      "#{base_class} nav-link-active"
    else
      base_class
    end
  end

  # Helper function for mobile nav links
  defp mobile_nav_link_class(current_path, link_path) do
    base_class = "nav-mobile-link"

    if String.starts_with?(current_path, link_path) do
      "#{base_class} nav-mobile-link-active"
    else
      base_class
    end
  end
end
