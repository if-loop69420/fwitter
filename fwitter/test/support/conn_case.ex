defmodule FwitterWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use FwitterWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import FwitterWeb.ConnCase

      alias FwitterWeb.Router.Helpers, as: Routes

      # The default endpoint for testing
      @endpoint FwitterWeb.Endpoint
    end
  end

  setup tags do
    Fwitter.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that registers and logs in auth_users.

      setup :register_and_log_in_auth_user

  It stores an updated connection and a registered auth_user in the
  test context.
  """
  def register_and_log_in_auth_user(%{conn: conn}) do
    auth_user = Fwitter.AuthAccsFixtures.auth_user_fixture()
    %{conn: log_in_auth_user(conn, auth_user), auth_user: auth_user}
  end

  @doc """
  Logs the given `auth_user` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_auth_user(conn, auth_user) do
    token = Fwitter.AuthAccs.generate_auth_user_session_token(auth_user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:auth_user_token, token)
  end
end
