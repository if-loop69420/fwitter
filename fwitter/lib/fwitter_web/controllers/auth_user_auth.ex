defmodule FwitterWeb.AuthUserAuth do
  import Plug.Conn
  import Phoenix.Controller

  alias Fwitter.AuthAccs
  alias FwitterWeb.Router.Helpers, as: Routes

  # Make the remember me cookie valid for 60 days.
  # If you want bump or reduce this value, also change
  # the token expiry itself in AuthUserToken.
  @max_age 60 * 60 * 24 * 60
  @remember_me_cookie "_fwitter_web_auth_user_remember_me"
  @remember_me_options [sign: true, max_age: @max_age, same_site: "Lax"]

  @doc """
  Logs the auth_user in.

  It renews the session ID and clears the whole session
  to avoid fixation attacks. See the renew_session
  function to customize this behaviour.

  It also sets a `:live_socket_id` key in the session,
  so LiveView sessions are identified and automatically
  disconnected on log out. The line can be safely removed
  if you are not using LiveView.
  """
  def log_in_auth_user(conn, auth_user, params \\ %{}) do
    token = AuthAccs.generate_auth_user_session_token(auth_user)
    auth_user_return_to = get_session(conn, :auth_user_return_to)

    conn
    |> renew_session()
    |> put_session(:auth_user_token, token)
    |> put_session(:live_socket_id, "auth_users_sessions:#{Base.url_encode64(token)}")
    |> maybe_write_remember_me_cookie(token, params)
    |> redirect(to: auth_user_return_to || signed_in_path(conn))
  end

  defp maybe_write_remember_me_cookie(conn, token, %{"remember_me" => "true"}) do
    put_resp_cookie(conn, @remember_me_cookie, token, @remember_me_options)
  end

  defp maybe_write_remember_me_cookie(conn, _token, _params) do
    conn
  end

  # This function renews the session ID and erases the whole
  # session to avoid fixation attacks. If there is any data
  # in the session you may want to preserve after log in/log out,
  # you must explicitly fetch the session data before clearing
  # and then immediately set it after clearing, for example:
  #
  #     defp renew_session(conn) do
  #       preferred_locale = get_session(conn, :preferred_locale)
  #
  #       conn
  #       |> configure_session(renew: true)
  #       |> clear_session()
  #       |> put_session(:preferred_locale, preferred_locale)
  #     end
  #
  defp renew_session(conn) do
    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  @doc """
  Logs the auth_user out.

  It clears all session data for safety. See renew_session.
  """
  def log_out_auth_user(conn) do
    auth_user_token = get_session(conn, :auth_user_token)
    auth_user_token && AuthAccs.delete_session_token(auth_user_token)

    if live_socket_id = get_session(conn, :live_socket_id) do
      FwitterWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> delete_resp_cookie(@remember_me_cookie)
    |> redirect(to: "/")
  end

  @doc """
  Authenticates the auth_user by looking into the session
  and remember me token.
  """
  def fetch_current_auth_user(conn, _opts) do
    {auth_user_token, conn} = ensure_auth_user_token(conn)
    auth_user = auth_user_token && AuthAccs.get_auth_user_by_session_token(auth_user_token)
    assign(conn, :current_auth_user, auth_user)
  end

  defp ensure_auth_user_token(conn) do
    if auth_user_token = get_session(conn, :auth_user_token) do
      {auth_user_token, conn}
    else
      conn = fetch_cookies(conn, signed: [@remember_me_cookie])

      if auth_user_token = conn.cookies[@remember_me_cookie] do
        {auth_user_token, put_session(conn, :auth_user_token, auth_user_token)}
      else
        {nil, conn}
      end
    end
  end

  @doc """
  Used for routes that require the auth_user to not be authenticated.
  """
  def redirect_if_auth_user_is_authenticated(conn, _opts) do
    if conn.assigns[:current_auth_user] do
      conn
      |> redirect(to: signed_in_path(conn))
      |> halt()
    else
      conn
    end
  end

  @doc """
  Used for routes that require the auth_user to be authenticated.

  If you want to enforce the auth_user email is confirmed before
  they use the application at all, here would be a good place.
  """
  def require_authenticated_auth_user(conn, _opts) do
    if conn.assigns[:current_auth_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> maybe_store_return_to()
      |> redirect(to: Routes.auth_user_session_path(conn, :new))
      |> halt()
    end
  end

  defp maybe_store_return_to(%{method: "GET"} = conn) do
    put_session(conn, :auth_user_return_to, current_path(conn))
  end

  defp maybe_store_return_to(conn), do: conn

  defp signed_in_path(_conn), do: "/"
end
