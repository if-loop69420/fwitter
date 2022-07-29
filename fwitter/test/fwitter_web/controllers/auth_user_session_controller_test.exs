defmodule FwitterWeb.AuthUserSessionControllerTest do
  use FwitterWeb.ConnCase, async: true

  import Fwitter.AuthAccsFixtures

  setup do
    %{auth_user: auth_user_fixture()}
  end

  describe "GET /auth_users/log_in" do
    test "renders log in page", %{conn: conn} do
      conn = get(conn, Routes.auth_user_session_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Log in</h1>"
      assert response =~ "Register</a>"
      assert response =~ "Forgot your password?</a>"
    end

    test "redirects if already logged in", %{conn: conn, auth_user: auth_user} do
      conn = conn |> log_in_auth_user(auth_user) |> get(Routes.auth_user_session_path(conn, :new))
      assert redirected_to(conn) == "/"
    end
  end

  describe "POST /auth_users/log_in" do
    test "logs the auth_user in", %{conn: conn, auth_user: auth_user} do
      conn =
        post(conn, Routes.auth_user_session_path(conn, :create), %{
          "auth_user" => %{"email" => auth_user.email, "password" => valid_auth_user_password()}
        })

      assert get_session(conn, :auth_user_token)
      assert redirected_to(conn) == "/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/")
      response = html_response(conn, 200)
      assert response =~ auth_user.email
      assert response =~ "Settings</a>"
      assert response =~ "Log out</a>"
    end

    test "logs the auth_user in with remember me", %{conn: conn, auth_user: auth_user} do
      conn =
        post(conn, Routes.auth_user_session_path(conn, :create), %{
          "auth_user" => %{
            "email" => auth_user.email,
            "password" => valid_auth_user_password(),
            "remember_me" => "true"
          }
        })

      assert conn.resp_cookies["_fwitter_web_auth_user_remember_me"]
      assert redirected_to(conn) == "/"
    end

    test "logs the auth_user in with return to", %{conn: conn, auth_user: auth_user} do
      conn =
        conn
        |> init_test_session(auth_user_return_to: "/foo/bar")
        |> post(Routes.auth_user_session_path(conn, :create), %{
          "auth_user" => %{
            "email" => auth_user.email,
            "password" => valid_auth_user_password()
          }
        })

      assert redirected_to(conn) == "/foo/bar"
    end

    test "emits error message with invalid credentials", %{conn: conn, auth_user: auth_user} do
      conn =
        post(conn, Routes.auth_user_session_path(conn, :create), %{
          "auth_user" => %{"email" => auth_user.email, "password" => "invalid_password"}
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Log in</h1>"
      assert response =~ "Invalid email or password"
    end
  end

  describe "DELETE /auth_users/log_out" do
    test "logs the auth_user out", %{conn: conn, auth_user: auth_user} do
      conn = conn |> log_in_auth_user(auth_user) |> delete(Routes.auth_user_session_path(conn, :delete))
      assert redirected_to(conn) == "/"
      refute get_session(conn, :auth_user_token)
      assert get_flash(conn, :info) =~ "Logged out successfully"
    end

    test "succeeds even if the auth_user is not logged in", %{conn: conn} do
      conn = delete(conn, Routes.auth_user_session_path(conn, :delete))
      assert redirected_to(conn) == "/"
      refute get_session(conn, :auth_user_token)
      assert get_flash(conn, :info) =~ "Logged out successfully"
    end
  end
end
