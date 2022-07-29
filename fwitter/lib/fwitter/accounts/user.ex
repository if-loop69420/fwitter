defmodule Fwitter.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :followers, :integer, default: 0
    field :username, :string

    timestamps()
    has_many :posts, Fwitter.Dashboard.Post  
    has_one :auth_users, Fwitter.AuthAccs.AuthUser, foreign_key: :id
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :followers])
    |> validate_required([:username, :followers])
  end
end
