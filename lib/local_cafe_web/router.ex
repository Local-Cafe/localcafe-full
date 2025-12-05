defmodule LocalCafeWeb.Router do
  use LocalCafeWeb, :router

  import LocalCafeWeb.UserAuth
  import LocalCafeWeb.Analytics

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LocalCafeWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug :write_analytics
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :fetch_current_scope_for_user
    plug :write_analytics
  end

  pipeline :webhook do
    plug :accepts, ["json"]
    # Note: Raw body is cached by CacheBodyReader in the endpoint (before parsing)
  end

  scope "/", LocalCafeWeb do
    pipe_through [:browser, :require_admin]

    get "/posts/new", PostController, :new
    post "/posts", PostController, :create
    get "/posts/:slug/edit", PostController, :edit
    put "/posts/:slug", PostController, :update
    patch "/posts/:slug", PostController, :update
    delete "/posts/:slug", PostController, :delete

    get "/admin", AdminDashboardController, :index
    get "/admin/analytics", AdminAnalyticsController, :index
    get "/admin/billing", AdminBillingController, :index
    get "/admin/billing/:id", AdminBillingController, :show
    get "/admin/comments", AdminCommentsController, :index
    get "/admin/users", AdminUsersController, :index
    post "/admin/users/:id/toggle-admin", AdminUsersController, :toggle_admin
    post "/admin/users/:id/toggle-trusted", AdminUsersController, :toggle_trusted

    post "/comments/:id/approve", CommentController, :approve
  end

  # Authenticated user routes
  scope "/", LocalCafeWeb do
    pipe_through [:browser, :require_authenticated_user]

    post "/posts/:slug/comments", CommentController, :create
    delete "/comments/:id", CommentController, :delete
  end

  # JSON API routes
  scope "/api", LocalCafeWeb do
    pipe_through :api
    get "/posts", PostController, :index_json
  end

  # Admin-only API routes
  scope "/api", LocalCafeWeb do
    pipe_through [:api, :require_admin]

    post "/presigned-url", PresignedUrlController, :generate
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:local_cafe, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LocalCafeWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", LocalCafeWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", LocalCafeWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email

    get "/payments", PaymentController, :index
  end

  scope "/", LocalCafeWeb do
    pipe_through [:browser]
    get "/", PageController, :home
    get "/posts", PostController, :index
    get "/posts/tags/:tag", PostController, :tag
    get "/posts/:slug", PostController, :show

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end

  # Webhook routes (bypass CSRF protection, use raw body for signature verification)
  scope "/webhooks", LocalCafeWeb do
    pipe_through :webhook

    post "/stripe", WebhookController, :stripe
  end
end
