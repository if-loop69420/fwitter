defmodule FwitterWeb.AuthUserSettingsControllerTest do
  use FwitterWeb.ConnCase, async: true

  alias Fwitter.AuthAccs
  import Fwitter.AuthAccsFixtures

  setup :register_and_log_in_auth_user

  describe "GET /auth_users/settings" do
    test "renders settings page", %{conn: conn} do
      conn = get(conn, Routes.auth_user_settings_path(conn, :edit))
      response = html_response(conn, 200)
      assert response =~ "<h1>Settings</h1>"
    end

    test "redirects if auth_user is not logged in" do
      conn = build_conn()
      conn = get(conn, Routes.auth_user_settings_path(conn, :edit))
      assert redirected_to(conn) == Routes.auth_user_session_path(conn, :new)
    end
  end

  describe "PUT /auth_users/settings (change password form)" do
    test "updates the auth_user password and resets tokens", %{conn: conn, auth_user: auth_user} do
      new_password_conn =
        put(conn, Routes.auth_user_settings_path(conn, :update), %{
          "action" => "update_password",
          "current_password" => valid_auth_user_password(),
          "auth_user" => %{
            "password" => "new valid password",
            "password_confirmation" => "new valid password"
          }
        })

      assert redirected_to(new_password_conn) == Routes.auth_user_settings_path(conn, :edit)
      assert get_session(new_password_conn, :auth_user_token) != get_session(conn, :auth_user_token)
      assert get_flash(new_password_conn, :info) =~ "Password updated successfully"
      assert AuthAccs.get_auth_user_by_email_and_password(auth_user.email, "new valid password")
    end

    test "does not update password on invalid data", %{conn: conn} do
      old_password_conn =
        put(conn, Routes.auth_user_settings_path(conn, :update), %{
          "action" => "update_password",
          "current_password" => "invalid",
          "auth_user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      response = html_response(old_password_conn, 200)
      assert response =~ "<h1>Settings</h1>"
      assert response =~ "should be at least 12 character(s)"
      assert response =~ "does not match password"
      assert response =~ "is not valid"

      assert get_session(old_password_conn, :auth_user_token) == get_session(conn, :auth_user_token)
    end
  end

  describe "PUT /auth_users/settings (change email form)" do
    @tag :capture_log
    test "updates the auth_user email", %{conn: conn, auth_user: auth_user} do
      conn =
        put(conn, Routes.auth_user_settings_path(conn, :update), %{
          "action" => "update_email",
          "current_password" => valid_auth_user_password(),
          "auth_user" => %{"email" => unique_auth_user_email()}
        })

      assert redirected_to(conn) == Routes.auth_user_settings_path(conn, :edit)
      assert get_flash(conn, :info) =~ "A link to confirm your email"
      assert AuthAccs.get_auth_user_by_email(auth_user.email)
    end

    test "does not update email on invalid data", %{conn: conn} do
      conn =
        put(conn, Routes.auth_user_settings_path(conn, :update), %{
          "action" => "update_email",
          "current_password" => "invalid",
          "auth_user" => %{"email" => "with spaces"}
        })

      response = html_response(conn, 200)
      assert response =~ "<h1>Settings</h1>"
      assert response =~ "must have the @ sign and no spaces"
      assert response =~ "is not valid"
    end
  end

  describe "GET /auth_users/settings/confirm_email/:token" do
    setup %{auth_user: auth_user} do
      email = unique_auth_user_email()

      token =
        extract_auth_user_token(fn url ->
          AuthAccs.deliver_update_email_instructions(%{auth_user | email: email}, auth_user.email, url)
        end)

      %{token: token, email: email}
    end

    test "updates the auth_user email once", %{conn: conn, auth_user: auth_user, token: token, email: email} do
      conn = get(conn, Routes.auth_user_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.auth_user_settings_path(conn, :edit)
      assert get_flash(conn, :info) =~ "Email changed successfully"
      refute AuthAccs.get_auth_user_by_email(auth_user.email)
      assert AuthAccs.get_auth_user_by_email(email)

      conn = get(conn, Routes.auth_user_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.auth_user_settings_path(conn, :edit)
      assert get_flash(conn, :error) =~ "Email change link is invalid or it has expired"
    end

    test "does not update email with invalid token", %{conn: conn, auth_user: auth_user} do
      conn = get(conn, Routes.auth_user_settings_path(conn, :confirm_email, "oops"))
      assert redirected_to(conn) == Routes.auth_user_settings_path(conn, :edit)
      assert get_flash(conn, :error) =~ "Email change link is invalid or it has expired"
      assert AuthAccs.get_auth_user_by_email(auth_user.email)
    end

    test "redirects if auth_user is not logged in", %{token: token} do
      conn = build_conn()
      conn = get(conn, Routes.auth_user_settings_path(conn, :confirm_email, token))
      assert redirected_to(conn) == Routes.auth_user_session_path(conn, :new)
    end
  end
end
