defmodule FwitterWeb.Router do
  use FwitterWeb, :router

  import FwitterWeb.AuthUserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {FwitterWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_auth_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", FwitterWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  # Other scopes may use custom stacks.
  # scope "/api", FwitterWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: FwitterWeb.Telemetry
    end
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", FwitterWeb do
    pipe_through [:browser, :redirect_if_auth_user_is_authenticated]

    get "/auth_users/register", AuthUserRegistrationController, :new
    post "/auth_users/register", AuthUserRegistrationController, :create
    get "/auth_users/log_in", AuthUserSessionController, :new
    post "/auth_users/log_in", AuthUserSessionController, :create
    get "/auth_users/reset_password", AuthUserResetPasswordController, :new
    post "/auth_users/reset_password", AuthUserResetPasswordController, :create
    get "/auth_users/reset_password/:token", AuthUserResetPasswordController, :edit
    put "/auth_users/reset_password/:token", AuthUserResetPasswordController, :update
  end

  scope "/", FwitterWeb do
    pipe_through [:browser, :require_authenticated_auth_user]

    get "/auth_users/settings", AuthUserSettingsController, :edit
    put "/auth_users/settings", AuthUserSettingsController, :update
    get "/auth_users/settings/confirm_email/:token", AuthUserSettingsController, :confirm_email
  end

  scope "/", FwitterWeb do
    pipe_through [:browser]

    delete "/auth_users/log_out", AuthUserSessionController, :delete
    get "/auth_users/confirm", AuthUserConfirmationController, :new
    post "/auth_users/confirm", AuthUserConfirmationController, :create
    get "/auth_users/confirm/:token", AuthUserConfirmationController, :edit
    post "/auth_users/confirm/:token", AuthUserConfirmationController, :update
  end
end
