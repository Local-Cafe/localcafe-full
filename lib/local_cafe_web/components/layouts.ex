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

  slot :inner_block, required: true
  slot :title
  slot :admin_bar

  def app(assigns) do
    ~H"""
    <header class="site-header">
      <nav class="site-nav">
        <div class="nav-container">
          <div class="nav-content">
            <div class="mobile-menu-button">
              <button
                type="button"
                command="--toggle"
                commandfor="mobile-menu"
                class="nav-toggle"
              >
                <span class="nav-toggle-inset"></span>
                <span class="sr-only">Open main menu</span>
                <svg
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  aria-hidden="true"
                  class="nav-icon nav-icon-menu in-aria-expanded:hidden"
                >
                  <path
                    d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  />
                </svg>
                <svg
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="1.5"
                  aria-hidden="true"
                  class="nav-icon nav-icon-close not-in-aria-expanded:hidden"
                >
                  <path d="M6 18 18 6M6 6l12 12" stroke-linecap="round" stroke-linejoin="round" />
                </svg>
              </button>
            </div>
            <div class="nav-left">
              <div class="nav-logo">
                <.link href={~p"/"}>
                  [FS]
                </.link>
              </div>
              <div class="nav-links-desktop">
                <div class="nav-links">
                  <.link href={~p"/posts"} class={nav_link_class(@current_path, "/posts")}>
                    Posts
                  </.link>
                </div>
              </div>
            </div>
            <div class="nav-right">
              <button type="button" class="theme-toggle" aria-label="Toggle theme">
                <span class="theme-toggle-icon"></span>
              </button>
              <%= if @current_scope do %>
                <button type="button" class="nav-notification">
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
                </button>

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
                      <.link href={~p"/payments"} class="nav-dropdown-item">
                        Payments
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
                  <.link href={~p"/users/register"} class="nav-link">
                    Register
                  </.link>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <el-disclosure id="mobile-menu" hidden class="nav-mobile-menu">
          <div class="nav-mobile-content">
            <div class="nav-mobile-theme">
              <span class="nav-mobile-theme-label">Theme</span>
              <button type="button" class="theme-toggle theme-toggle-mobile" aria-label="Toggle theme">
                <span class="theme-toggle-icon"></span>
                <span class="theme-toggle-label">System</span>
              </button>
            </div>
            <.link href={~p"/posts"} class={mobile_nav_link_class(@current_path, "/posts")}>
              Posts
            </.link>
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
              <.link href={~p"/users/register"} class="nav-mobile-link">
                Register
              </.link>
            <% end %>
          </div>
        </el-disclosure>
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
    <div :if={@title != []} class="title-wrap">
      <div class="title">
        {render_slot(@title)}
      </div>
    </div>
    <main class="main-content">
      <div class="content-container">
        {render_slot(@inner_block)}
      </div>
    </main>

    <footer class="site-footer">
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
          </div>
          <nav class="footer-nav">
            <.link href={~p"/"} class="footer-nav-link">Foobar</.link>
          </nav>
          <p class="footer-copyright">
            &copy; {DateTime.utc_now().year} LocalCafe.org ~ All rights reserved. Est: MMXXV <svg
              class="tree-icon svelte-jz8lnl"
              version="1.1"
              x="0px"
              y="0px"
              viewBox="0 0 100 100"
            ><switch><g><path d="M86.3,76L73.2,58.2h4c1.1,0,2-0.6,2.5-1.5c0.5-0.9,0.4-2.1-0.2-2.9L66.4,35.9h4c1.1,0,2-0.6,2.5-1.5    c0.5-0.9,0.4-2.1-0.2-2.9L52.2,3.6c-1-1.4-3.4-1.4-4.5,0L27.3,31.4c-0.6,0.8-0.7,2-0.2,2.9c0.5,0.9,1.4,1.5,2.5,1.5h4L20.5,53.7    c-0.6,0.8-0.7,2-0.2,2.9c0.5,0.9,1.4,1.5,2.5,1.5h4L13.7,76c-0.6,0.8-0.7,2-0.2,2.9c0.5,0.9,1.4,1.5,2.5,1.5h29.3v12.3    c0,2.6,2.1,4.7,4.7,4.7c2.6,0,4.7-2.1,4.7-4.7V80.4h29.3c1.1,0,2-0.6,2.5-1.5C87,78,86.9,76.9,86.3,76z M21.4,74.9L34.5,57    c0.6-0.8,0.7-2,0.2-2.9c-0.5-0.9-1.4-1.5-2.5-1.5h-4l13.1-17.9c0.6-0.8,0.7-2,0.2-2.9c-0.5-0.9-1.4-1.5-2.5-1.5h-4L50,9.9    l14.9,20.4h-4c-1.1,0-2,0.6-2.5,1.5c-0.5,0.9-0.4,2.1,0.2,2.9l13.1,17.9h-4c-1.1,0-2,0.6-2.5,1.5c-0.5,0.9-0.4,2.1,0.2,2.9    l13.1,17.9H21.4z"></path></g></switch></svg>Portland, OR
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
