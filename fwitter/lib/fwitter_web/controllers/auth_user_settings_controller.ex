defmodule FwitterWeb.AuthUserSettingsController do
  use FwitterWeb, :controller

  alias Fwitter.AuthAccs
  alias FwitterWeb.AuthUserAuth

  plug :assign_email_and_password_changesets

  def edit(conn, _params) do
    render(conn, "edit.html")
  end

  def update(conn, %{"action" => "update_email"} = params) do
    %{"current_password" => password, "auth_user" => auth_user_params} = params
    auth_user = conn.assigns.current_auth_user

    case AuthAccs.apply_auth_user_email(auth_user, password, auth_user_params) do
      {:ok, applied_auth_user} ->
        AuthAccs.deliver_update_email_instructions(
          applied_auth_user,
          auth_user.email,
          &Routes.auth_user_settings_url(conn, :confirm_email, &1)
        )

        conn
        |> put_flash(
          :info,
          "A link to confirm your email change has been sent to the new address."
        )
        |> redirect(to: Routes.auth_user_settings_path(conn, :edit))

      {:error, changeset} ->
        render(conn, "edit.html", email_changeset: changeset)
    end
  end

  def update(conn, %{"action" => "update_password"} = params) do
    %{"current_password" => password, "auth_user" => auth_user_params} = params
    auth_user = conn.assigns.current_auth_user

    case AuthAccs.update_auth_user_password(auth_user, password, auth_user_params) do
      {:ok, auth_user} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> put_session(:auth_user_return_to, Routes.auth_user_settings_path(conn, :edit))
        |> AuthUserAuth.log_in_auth_user(auth_user)

      {:error, changeset} ->
        render(conn, "edit.html", password_changeset: changeset)
    end
  end

  def confirm_email(conn, %{"token" => token}) do
    case AuthAccs.update_auth_user_email(conn.assigns.current_auth_user, token) do
      :ok ->
        conn
        |> put_flash(:info, "Email changed successfully.")
        |> redirect(to: Routes.auth_user_settings_path(conn, :edit))

      :error ->
        conn
        |> put_flash(:error, "Email change link is invalid or it has expired.")
        |> redirect(to: Routes.auth_user_settings_path(conn, :edit))
    end
  end

  defp assign_email_and_password_changesets(conn, _opts) do
    auth_user = conn.assigns.current_auth_user

    conn
    |> assign(:email_changeset, AuthAccs.change_auth_user_email(auth_user))
    |> assign(:password_changeset, AuthAccs.change_auth_user_password(auth_user))
  end
end
