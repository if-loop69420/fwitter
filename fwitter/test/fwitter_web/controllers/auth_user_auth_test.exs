defmodule FwitterWeb.AuthUserAuthTest do
  use FwitterWeb.ConnCase, async: true

  alias Fwitter.AuthAccs
  alias FwitterWeb.AuthUserAuth
  import Fwitter.AuthAccsFixtures

  @remember_me_cookie "_fwitter_web_auth_user_remember_me"

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, FwitterWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{auth_user: auth_user_fixture(), conn: conn}
  end

  describe "log_in_auth_user/3" do
    test "stores the auth_user token in the session", %{conn: conn, auth_user: auth_user} do
      conn = AuthUserAuth.log_in_auth_user(conn, auth_user)
      assert token = get_session(conn, :auth_user_token)
      assert get_session(conn, :live_socket_id) == "auth_users_sessions:#{Base.url_encode64(token)}"
      assert redirected_to(conn) == "/"
      assert AuthAccs.get_auth_user_by_session_token(token)
    end

    test "clears everything previously stored in the session", %{conn: conn, auth_user: auth_user} do
      conn = conn |> put_session(:to_be_removed, "value") |> AuthUserAuth.log_in_auth_user(auth_user)
      refute get_session(conn, :to_be_removed)
    end

    test "redirects to the configured path", %{conn: conn, auth_user: auth_user} do
      conn = conn |> put_session(:auth_user_return_to, "/hello") |> AuthUserAuth.log_in_auth_user(auth_user)
      assert redirected_to(conn) == "/hello"
    end

    test "writes a cookie if remember_me is configured", %{conn: conn, auth_user: auth_user} do
      conn = conn |> fetch_cookies() |> AuthUserAuth.log_in_auth_user(auth_user, %{"remember_me" => "true"})
      assert get_session(conn, :auth_user_token) == conn.cookies[@remember_me_cookie]

      assert %{value: signed_token, max_age: max_age} = conn.resp_cookies[@remember_me_cookie]
      assert signed_token != get_session(conn, :auth_user_token)
      assert max_age == 5_184_000
    end
  end

  describe "logout_auth_user/1" do
    test "erases session and cookies", %{conn: conn, auth_user: auth_user} do
      auth_user_token = AuthAccs.generate_auth_user_session_token(auth_user)

      conn =
        conn
        |> put_session(:auth_user_token, auth_user_token)
        |> put_req_cookie(@remember_me_cookie, auth_user_token)
        |> fetch_cookies()
        |> AuthUserAuth.log_out_auth_user()

      refute get_session(conn, :auth_user_token)
      refute conn.cookies[@remember_me_cookie]
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == "/"
      refute AuthAccs.get_auth_user_by_session_token(auth_user_token)
    end

    test "broadcasts to the given live_socket_id", %{conn: conn} do
      live_socket_id = "auth_users_sessions:abcdef-token"
      FwitterWeb.Endpoint.subscribe(live_socket_id)

      conn
      |> put_session(:live_socket_id, live_socket_id)
      |> AuthUserAuth.log_out_auth_user()

      assert_receive %Phoenix.Socket.Broadcast{event: "disconnect", topic: ^live_socket_id}
    end

    test "works even if auth_user is already logged out", %{conn: conn} do
      conn = conn |> fetch_cookies() |> AuthUserAuth.log_out_auth_user()
      refute get_session(conn, :auth_user_token)
      assert %{max_age: 0} = conn.resp_cookies[@remember_me_cookie]
      assert redirected_to(conn) == "/"
    end
  end

  describe "fetch_current_auth_user/2" do
    test "authenticates auth_user from session", %{conn: conn, auth_user: auth_user} do
      auth_user_token = AuthAccs.generate_auth_user_session_token(auth_user)
      conn = conn |> put_session(:auth_user_token, auth_user_token) |> AuthUserAuth.fetch_current_auth_user([])
      assert conn.assigns.current_auth_user.id == auth_user.id
    end

    test "authenticates auth_user from cookies", %{conn: conn, auth_user: auth_user} do
      logged_in_conn =
        conn |> fetch_cookies() |> AuthUserAuth.log_in_auth_user(auth_user, %{"remember_me" => "true"})

      auth_user_token = logged_in_conn.cookies[@remember_me_cookie]
      %{value: signed_token} = logged_in_conn.resp_cookies[@remember_me_cookie]

      conn =
        conn
        |> put_req_cookie(@remember_me_cookie, signed_token)
        |> AuthUserAuth.fetch_current_auth_user([])

      assert get_session(conn, :auth_user_token) == auth_user_token
      assert conn.assigns.current_auth_user.id == auth_user.id
    end

    test "does not authenticate if data is missing", %{conn: conn, auth_user: auth_user} do
      _ = AuthAccs.generate_auth_user_session_token(auth_user)
      conn = AuthUserAuth.fetch_current_auth_user(conn, [])
      refute get_session(conn, :auth_user_token)
      refute conn.assigns.current_auth_user
    end
  end

  describe "redirect_if_auth_user_is_authenticated/2" do
    test "redirects if auth_user is authenticated", %{conn: conn, auth_user: auth_user} do
      conn = conn |> assign(:current_auth_user, auth_user) |> AuthUserAuth.redirect_if_auth_user_is_authenticated([])
      assert conn.halted
      assert redirected_to(conn) == "/"
    end

    test "does not redirect if auth_user is not authenticated", %{conn: conn} do
      conn = AuthUserAuth.redirect_if_auth_user_is_authenticated(conn, [])
      refute conn.halted
      refute conn.status
    end
  end

  describe "require_authenticated_auth_user/2" do
    test "redirects if auth_user is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> AuthUserAuth.require_authenticated_auth_user([])
      assert conn.halted
      assert redirected_to(conn) == Routes.auth_user_session_path(conn, :new)
      assert get_flash(conn, :error) == "You must log in to access this page."
    end

    test "stores the path to redirect to on GET", %{conn: conn} do
      halted_conn =
        %{conn | path_info: ["foo"], query_string: ""}
        |> fetch_flash()
        |> AuthUserAuth.require_authenticated_auth_user([])

      assert halted_conn.halted
      assert get_session(halted_conn, :auth_user_return_to) == "/foo"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar=baz"}
        |> fetch_flash()
        |> AuthUserAuth.require_authenticated_auth_user([])

      assert halted_conn.halted
      assert get_session(halted_conn, :auth_user_return_to) == "/foo?bar=baz"

      halted_conn =
        %{conn | path_info: ["foo"], query_string: "bar", method: "POST"}
        |> fetch_flash()
        |> AuthUserAuth.require_authenticated_auth_user([])

      assert halted_conn.halted
      refute get_session(halted_conn, :auth_user_return_to)
    end

    test "does not redirect if auth_user is authenticated", %{conn: conn, auth_user: auth_user} do
      conn = conn |> assign(:current_auth_user, auth_user) |> AuthUserAuth.require_authenticated_auth_user([])
      refute conn.halted
      refute conn.status
    end
  end
end
