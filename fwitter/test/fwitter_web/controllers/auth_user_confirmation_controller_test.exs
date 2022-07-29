defmodule FwitterWeb.AuthUserConfirmationControllerTest do
  use FwitterWeb.ConnCase, async: true

  alias Fwitter.AuthAccs
  alias Fwitter.Repo
  import Fwitter.AuthAccsFixtures

  setup do
    %{auth_user: auth_user_fixture()}
  end

  describe "GET /auth_users/confirm" do
    test "renders the resend confirmation page", %{conn: conn} do
      conn = get(conn, Routes.auth_user_confirmation_path(conn, :new))
      response = html_response(conn, 200)
      assert response =~ "<h1>Resend confirmation instructions</h1>"
    end
  end

  describe "POST /auth_users/confirm" do
    @tag :capture_log
    test "sends a new confirmation token", %{conn: conn, auth_user: auth_user} do
      conn =
        post(conn, Routes.auth_user_confirmation_path(conn, :create), %{
          "auth_user" => %{"email" => auth_user.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.get_by!(AuthAccs.AuthUserToken, auth_user_id: auth_user.id).context == "confirm"
    end

    test "does not send confirmation token if Auth user is confirmed", %{conn: conn, auth_user: auth_user} do
      Repo.update!(AuthAccs.AuthUser.confirm_changeset(auth_user))

      conn =
        post(conn, Routes.auth_user_confirmation_path(conn, :create), %{
          "auth_user" => %{"email" => auth_user.email}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      refute Repo.get_by(AuthAccs.AuthUserToken, auth_user_id: auth_user.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      conn =
        post(conn, Routes.auth_user_confirmation_path(conn, :create), %{
          "auth_user" => %{"email" => "unknown@example.com"}
        })

      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "If your email is in our system"
      assert Repo.all(AuthAccs.AuthUserToken) == []
    end
  end

  describe "GET /auth_users/confirm/:token" do
    test "renders the confirmation page", %{conn: conn} do
      conn = get(conn, Routes.auth_user_confirmation_path(conn, :edit, "some-token"))
      response = html_response(conn, 200)
      assert response =~ "<h1>Confirm account</h1>"

      form_action = Routes.auth_user_confirmation_path(conn, :update, "some-token")
      assert response =~ "action=\"#{form_action}\""
    end
  end

  describe "POST /auth_users/confirm/:token" do
    test "confirms the given token once", %{conn: conn, auth_user: auth_user} do
      token =
        extract_auth_user_token(fn url ->
          AuthAccs.deliver_auth_user_confirmation_instructions(auth_user, url)
        end)

      conn = post(conn, Routes.auth_user_confirmation_path(conn, :update, token))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :info) =~ "Auth user confirmed successfully"
      assert AuthAccs.get_auth_user!(auth_user.id).confirmed_at
      refute get_session(conn, :auth_user_token)
      assert Repo.all(AuthAccs.AuthUserToken) == []

      # When not logged in
      conn = post(conn, Routes.auth_user_confirmation_path(conn, :update, token))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Auth user confirmation link is invalid or it has expired"

      # When logged in
      conn =
        build_conn()
        |> log_in_auth_user(auth_user)
        |> post(Routes.auth_user_confirmation_path(conn, :update, token))

      assert redirected_to(conn) == "/"
      refute get_flash(conn, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, auth_user: auth_user} do
      conn = post(conn, Routes.auth_user_confirmation_path(conn, :update, "oops"))
      assert redirected_to(conn) == "/"
      assert get_flash(conn, :error) =~ "Auth user confirmation link is invalid or it has expired"
      refute AuthAccs.get_auth_user!(auth_user.id).confirmed_at
    end
  end
end
