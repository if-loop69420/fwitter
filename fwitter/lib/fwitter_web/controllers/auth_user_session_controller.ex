defmodule FwitterWeb.AuthUserSessionController do
  use FwitterWeb, :controller

  alias Fwitter.AuthAccs
  alias FwitterWeb.AuthUserAuth

  def new(conn, _params) do
    render(conn, "new.html", error_message: nil)
  end

  def create(conn, %{"auth_user" => auth_user_params}) do
    %{"email" => email, "password" => password} = auth_user_params

    if auth_user = AuthAccs.get_auth_user_by_email_and_password(email, password) do
      AuthUserAuth.log_in_auth_user(conn, auth_user, auth_user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      render(conn, "new.html", error_message: "Invalid email or password")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> AuthUserAuth.log_out_auth_user()
  end
end
