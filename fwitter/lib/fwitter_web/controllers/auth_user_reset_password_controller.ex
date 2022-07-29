defmodule FwitterWeb.AuthUserResetPasswordController do
  use FwitterWeb, :controller

  alias Fwitter.AuthAccs

  plug :get_auth_user_by_reset_password_token when action in [:edit, :update]

  def new(conn, _params) do
    render(conn, "new.html")
  end

  def create(conn, %{"auth_user" => %{"email" => email}}) do
    if auth_user = AuthAccs.get_auth_user_by_email(email) do
      AuthAccs.deliver_auth_user_reset_password_instructions(
        auth_user,
        &Routes.auth_user_reset_password_url(conn, :edit, &1)
      )
    end

    conn
    |> put_flash(
      :info,
      "If your email is in our system, you will receive instructions to reset your password shortly."
    )
    |> redirect(to: "/")
  end

  def edit(conn, _params) do
    render(conn, "edit.html", changeset: AuthAccs.change_auth_user_password(conn.assigns.auth_user))
  end

  # Do not log in the auth_user after reset password to avoid a
  # leaked token giving the auth_user access to the account.
  def update(conn, %{"auth_user" => auth_user_params}) do
    case AuthAccs.reset_auth_user_password(conn.assigns.auth_user, auth_user_params) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Password reset successfully.")
        |> redirect(to: Routes.auth_user_session_path(conn, :new))

      {:error, changeset} ->
        render(conn, "edit.html", changeset: changeset)
    end
  end

  defp get_auth_user_by_reset_password_token(conn, _opts) do
    %{"token" => token} = conn.params

    if auth_user = AuthAccs.get_auth_user_by_reset_password_token(token) do
      conn |> assign(:auth_user, auth_user) |> assign(:token, token)
    else
      conn
      |> put_flash(:error, "Reset password link is invalid or it has expired.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
