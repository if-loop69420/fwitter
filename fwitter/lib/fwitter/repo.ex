defmodule Fwitter.Repo do
  use Ecto.Repo,
    otp_app: :fwitter,
    adapter: Ecto.Adapters.Postgres
end
