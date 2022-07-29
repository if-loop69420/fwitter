defmodule Fwitter.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Fwitter.Accounts` context.
  """

  @doc """
  Generate a user.
  """
  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        followers: 42,
        username: "some username"
      })
      |> Fwitter.Accounts.create_user()

    user
  end
end
