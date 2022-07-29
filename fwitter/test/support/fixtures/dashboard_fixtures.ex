defmodule Fwitter.DashboardFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Fwitter.Dashboard` context.
  """

  @doc """
  Generate a post.
  """
  def post_fixture(attrs \\ %{}) do
    {:ok, post} =
      attrs
      |> Enum.into(%{
        body: "some body",
        likes: 42
      })
      |> Fwitter.Dashboard.create_post()

    post
  end
end
