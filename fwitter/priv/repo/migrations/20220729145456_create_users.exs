defmodule Fwitter.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :username, :string
      add :followers, :integer

      timestamps()
    end
  end
end
