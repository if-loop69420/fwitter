defmodule FwitterWeb.AuthUserConfirmationController do
  use FwitterWeb, :controller

  alias Fwitter.AuthAccs

  def new(conn, _params) do
    render(conn, "new.html")
  end

  def create(conn, %{"auth_user" => %{"email" => email}}) do
    if auth_user = AuthAccs.get_auth_user_by_email(email) do
      AuthAccs.deliver_auth_user_confirmation_instructions(
        auth_user,
        &Routes.auth_user_confirmation_url(conn, :edit, &1)
      )
    end

    conn
    |> put_flash(
      :info,
      "If your email is in our system and it has not been confirmed yet, " <>
        "you will receive an email with instructions shortly."
    )
    |> redirect(to: "/")
  end

  def edit(conn, %{"token" => token}) do
    render(conn, "edit.html", token: token)
  end

  # Do not log in the auth_user after confirmation to avoid a
  # leaked token giving the auth_user access to the account.
  def update(conn, %{"token" => token}) do
    case AuthAccs.confirm_auth_user(token) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Auth user confirmed successfully.")
        |> redirect(to: "/")

      :error ->
        # If there is a current auth_user and the account was already confirmed,
        # then odds are that the confirmation link was already visited, either
        # by some automation or by the auth_user themselves, so we redirect without
        # a warning message.
        case conn.assigns do
          %{current_auth_user: %{confirmed_at: confirmed_at}} when not is_nil(confirmed_at) ->
            redirect(conn, to: "/")

          %{} ->
            conn
            |> put_flash(:error, "Auth user confirmation link is invalid or it has expired.")
            |> redirect(to: "/")
        end
    end
  end
end
