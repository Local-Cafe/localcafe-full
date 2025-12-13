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
    plug LocalCafeWeb.Plugs.AssignCartCount
    plug LocalCafeWeb.Plugs.AssignNotificationCount
    plug LocalCafeWeb.Plugs.AssignHasBlogPosts
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

  pipeline :require_order_access do
    plug LocalCafeWeb.Plugs.RequireOrderAccess
  end

  scope "/", LocalCafeWeb do
    pipe_through [:browser, :require_admin]

    get "/posts/new", PostController, :new
    post "/posts", PostController, :create
    get "/posts/:slug/edit", PostController, :edit
    put "/posts/:slug", PostController, :update
    patch "/posts/:slug", PostController, :update
    delete "/posts/:slug", PostController, :delete

    get "/menu/new", MenuItemController, :new
    post "/menu", MenuItemController, :create
    get "/menu/:slug/edit", MenuItemController, :edit
    put "/menu/:slug", MenuItemController, :update
    patch "/menu/:slug", MenuItemController, :update
    delete "/menu/:slug", MenuItemController, :delete

    get "/admin", AdminDashboardController, :index
    get "/admin/analytics", AdminAnalyticsController, :index
    get "/admin/billing", AdminBillingController, :index
    get "/admin/billing/:id", AdminBillingController, :show
    get "/admin/comments", AdminCommentsController, :index
    get "/admin/users", AdminUsersController, :index
    post "/admin/users/:id/toggle-admin", AdminUsersController, :toggle_admin
    post "/admin/users/:id/toggle-trusted", AdminUsersController, :toggle_trusted

    get "/admin/orders", AdminOrdersController, :index
    get "/admin/orders/:id", AdminOrdersController, :show
    post "/admin/orders/:id/update-status", AdminOrdersController, :update_status
    post "/admin/orders/:id/refund", AdminOrdersController, :refund

    get "/admin/locations", AdminLocationsController, :index
    get "/admin/locations/new", AdminLocationsController, :new
    post "/admin/locations", AdminLocationsController, :create
    get "/admin/locations/:slug", AdminLocationsController, :show
    get "/admin/locations/:slug/edit", AdminLocationsController, :edit
    put "/admin/locations/:slug", AdminLocationsController, :update
    patch "/admin/locations/:slug", AdminLocationsController, :update
    delete "/admin/locations/:slug", AdminLocationsController, :delete

    get "/admin/hero-slides", AdminHeroSlidesController, :index
    get "/admin/hero-slides/new", AdminHeroSlidesController, :new
    post "/admin/hero-slides", AdminHeroSlidesController, :create
    get "/admin/hero-slides/:id/edit", AdminHeroSlidesController, :edit
    put "/admin/hero-slides/:id", AdminHeroSlidesController, :update
    patch "/admin/hero-slides/:id", AdminHeroSlidesController, :update
    delete "/admin/hero-slides/:id", AdminHeroSlidesController, :delete

    post "/comments/:id/approve", CommentController, :approve
  end

  # Order view route (requires auth OR valid token)
  scope "/", LocalCafeWeb do
    pipe_through [:browser, :require_order_access]

    get "/my-orders/:id", OrderController, :show
  end

  # Authenticated user routes
  scope "/", LocalCafeWeb do
    pipe_through [:browser, :require_authenticated_user]

    post "/posts/:slug/comments", CommentController, :create
    delete "/comments/:id", CommentController, :delete

    get "/my-orders", OrderController, :index
    post "/my-orders/:id/cancel", OrderController, :cancel

    get "/notifications", NotificationController, :index
    get "/notifications/:id/view", NotificationController, :mark_as_viewed
    post "/notifications/mark-all-viewed", NotificationController, :mark_all_as_viewed
    post "/notifications/delete-all", NotificationController, :delete_all
  end

  # Notification API routes (for push subscription management)
  scope "/api/notifications", LocalCafeWeb do
    pipe_through [:api, :require_authenticated_user]

    get "/count", NotificationController, :count
    post "/subscribe", NotificationController, :subscribe
    post "/unsubscribe", NotificationController, :unsubscribe
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

    get "/menu/:slug", MenuItemController, :show
    post "/menu/:slug/order", OrderController, :create

    get "/cart", CartController, :index
    post "/cart/add", CartController, :add
    post "/cart/update-quantity", CartController, :update_quantity
    post "/cart/remove", CartController, :remove
    post "/cart/clear", CartController, :clear

    get "/checkout", CheckoutController, :new
    get "/checkout/payment", CheckoutController, :payment
    post "/checkout/payment", CheckoutController, :payment
    post "/checkout", CheckoutController, :create

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
