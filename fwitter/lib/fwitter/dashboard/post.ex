defmodule Fwitter.Dashboard.Post do
  use Ecto.Schema
  import Ecto.Changeset

  schema "posts" do
    field :body, :string
    field :likes, :integer, default: 0

    timestamps()

    belongs_to :users, Fwitter.Accounts.User, foreign_key: :user_id
  end

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, [:body, :likes])
    |> validate_required([:body, :likes])
  end
end
