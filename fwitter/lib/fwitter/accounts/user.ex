defmodule Fwitter.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :followers, :integer
    field :username, :string

    timestamps()
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :followers])
    |> validate_required([:username, :followers])
  end
end
