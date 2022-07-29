defmodule FwitterWeb.AuthUserResetPasswordControllerTest do
  use FwitterWeb.ConnCase, async: true

  alias Fwitter.AuthAccs
  alias Fwitter.Repo
  import Fwitter.AuthAccsFixtures

  setup do
    %{auth_user: auth_user_fixture()}
  end

  describe "GET /auth_users/reset_password" do
    test "renders the reset password page", %{conn: conn} do
      conn = get(conn, Routes.auth_user_reset_password_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Forgot your password?</h1>"
    end
  end

  describe "POST /auth_users/reset_password" do
    @tag :capture_log
    test "sends a new reset password token", %{conn: conn, auth_user: auth_user} do
      conn =
        post(conn, Routes.auth_user_reset_password_path(conn, :create), %{
          "auth_user" => %{"email" => auth_user.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.get_by!(AuthAccs.AuthUserToken, auth_user_id: auth_user.id).context == "reset_password"
    end

    test "does not send reset password token if email is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.auth_user_reset_password_path(conn, :create), %{
          "auth_user" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.all(AuthAccs.AuthUserToken) == []
    end
  end

  describe "GET /auth_users/reset_password/:token" do
    setup %{auth_user: auth_user} do
      token =
        extract_auth_user_token(fn url ->
          AuthAccs.deliver_auth_user_reset_password_instructions(auth_user, url)
        end)

      %{token: token}
    end

    test "renders reset password", %{conn: conn, token: token} do
      conn = get(conn, Routes.auth_user_reset_password_path(conn, :edit, token))
      assert html_response(conn, 200) =~ "<h1>Reset password</h1>"
    end

    test "does not render reset password with invalid token", %{conn: conn} do
      conn = get(conn, Routes.auth_user_reset_password_path(conn, :edit, "oops"))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Reset password link is invalid or it has expired"
    end
  end

  describe "PUT /auth_users/reset_password/:token" do
    setup %{auth_user: auth_user} do
      token =
        extract_auth_user_token(fn url ->
          AuthAccs.deliver_auth_user_reset_password_instructions(auth_user, url)
        end)

      %{token: token}
    end

    test "resets password once", %{conn: conn, auth_user: auth_user, token: token} do
      conn =
        put(conn, Routes.auth_user_reset_password_path(conn, :update, token), %{
          "auth_user" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(conn) == Routes.auth_user_session_path(conn, :new)
      refute get_session(conn, :auth_user_token)
      assert get_flash(conn, :info) =~ "Password reset successfully"
      assert AuthAccs.get_auth_user_by_email_and_password(auth_user.email, "new valid password")
    end

    test "does not reset password on invalid data", %{conn: conn, token: token} do
      conn =
        put(conn, Routes.auth_user_reset_password_path(conn, :update, token), %{
          "auth_user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Reset password</h1>"
      assert response =~ "should be at least 12 character(s)"
      assert response =~ "does not match password"
    end

    test "does not reset password with invalid token", %{conn: conn} do
      conn = put(conn, Routes.auth_user_reset_password_path(conn, :update, "oops"))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Reset password link is invalid or it has expired"
    end
  end
end
