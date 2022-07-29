defmodule Fwitter.AuthAccsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Fwitter.AuthAccs` context.
  """

  def unique_auth_user_email, do: "auth_user#{System.unique_integer()}@example.com"
  def valid_auth_user_password, do: "hello world!"

  def valid_auth_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_auth_user_email(),
      password: valid_auth_user_password()
    })
  end

  def auth_user_fixture(attrs \\ %{}) do
    {:ok, auth_user} =
      attrs
      |> valid_auth_user_attributes()
      |> Fwitter.AuthAccs.register_auth_user()

    auth_user
  end

  def extract_auth_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
