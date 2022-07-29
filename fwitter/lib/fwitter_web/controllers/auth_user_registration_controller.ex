defmodule FwitterWeb.AuthUserRegistrationController do
  use FwitterWeb, :controller

  alias Fwitter.AuthAccs
  alias Fwitter.AuthAccs.AuthUser
  alias FwitterWeb.AuthUserAuth

  def new(conn, _params) do
    changeset = AuthAccs.change_auth_user_registration(%AuthUser{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"auth_user" => auth_user_params}) do
    case AuthAccs.register_auth_user(auth_user_params) do
      {:ok, auth_user} ->
        {:ok, _} =
          AuthAccs.deliver_auth_user_confirmation_instructions(
            auth_user,
            &Routes.auth_user_confirmation_url(conn, :edit, &1)
          )

        conn
        |> put_flash(:info, "Auth user created successfully.")
        |> AuthUserAuth.log_in_auth_user(auth_user)

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end
end
