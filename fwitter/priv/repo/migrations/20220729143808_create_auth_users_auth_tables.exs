defmodule Fwitter.Repo.Migrations.CreateAuthUsersAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:auth_users) do
      add :email, :citext, null: false
      add :hashed_password, :string, null: false
      add :confirmed_at, :naive_datetime
      timestamps()
    end

    create unique_index(:auth_users, [:email])

    create table(:auth_users_tokens) do
      add :auth_user_id, references(:auth_users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create index(:auth_users_tokens, [:auth_user_id])
    create unique_index(:auth_users_tokens, [:context, :token])
  end
end
