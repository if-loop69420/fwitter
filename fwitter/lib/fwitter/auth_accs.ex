defmodule Fwitter.AuthAccs do
  @moduledoc """
  The AuthAccs context.
  """

  import Ecto.Query, warn: false
  alias Fwitter.Repo

  alias Fwitter.AuthAccs.{AuthUser, AuthUserToken, AuthUserNotifier}

  ## Database getters

  @doc """
  Gets a auth_user by email.

  ## Examples

      iex> get_auth_user_by_email("foo@example.com")
      %AuthUser{}

      iex> get_auth_user_by_email("unknown@example.com")
      nil

  """
  def get_auth_user_by_email(email) when is_binary(email) do
    Repo.get_by(AuthUser, email: email)
  end

  @doc """
  Gets a auth_user by email and password.

  ## Examples

      iex> get_auth_user_by_email_and_password("foo@example.com", "correct_password")
      %AuthUser{}

      iex> get_auth_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_auth_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    auth_user = Repo.get_by(AuthUser, email: email)
    if AuthUser.valid_password?(auth_user, password), do: auth_user
  end

  @doc """
  Gets a single auth_user.

  Raises `Ecto.NoResultsError` if the AuthUser does not exist.

  ## Examples

      iex> get_auth_user!(123)
      %AuthUser{}

      iex> get_auth_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_auth_user!(id), do: Repo.get!(AuthUser, id)

  ## Auth user registration

  @doc """
  Registers a auth_user.

  ## Examples

      iex> register_auth_user(%{field: value})
      {:ok, %AuthUser{}}

      iex> register_auth_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_auth_user(attrs) do
    %AuthUser{}
    |> AuthUser.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking auth_user changes.

  ## Examples

      iex> change_auth_user_registration(auth_user)
      %Ecto.Changeset{data: %AuthUser{}}

  """
  def change_auth_user_registration(%AuthUser{} = auth_user, attrs \\ %{}) do
    AuthUser.registration_changeset(auth_user, attrs, hash_password: false)
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the auth_user email.

  ## Examples

      iex> change_auth_user_email(auth_user)
      %Ecto.Changeset{data: %AuthUser{}}

  """
  def change_auth_user_email(auth_user, attrs \\ %{}) do
    AuthUser.email_changeset(auth_user, attrs)
  end

  @doc """
  Emulates that the email will change without actually changing
  it in the database.

  ## Examples

      iex> apply_auth_user_email(auth_user, "valid password", %{email: ...})
      {:ok, %AuthUser{}}

      iex> apply_auth_user_email(auth_user, "invalid password", %{email: ...})
      {:error, %Ecto.Changeset{}}

  """
  def apply_auth_user_email(auth_user, password, attrs) do
    auth_user
    |> AuthUser.email_changeset(attrs)
    |> AuthUser.validate_current_password(password)
    |> Ecto.Changeset.apply_action(:update)
  end

  @doc """
  Updates the auth_user email using the given token.

  If the token matches, the auth_user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_auth_user_email(auth_user, token) do
    context = "change:#{auth_user.email}"

    with {:ok, query} <- AuthUserToken.verify_change_email_token_query(token, context),
         %AuthUserToken{sent_to: email} <- Repo.one(query),
         {:ok, _} <- Repo.transaction(auth_user_email_multi(auth_user, email, context)) do
      :ok
    else
      _ -> :error
    end
  end

  defp auth_user_email_multi(auth_user, email, context) do
    changeset =
      auth_user
      |> AuthUser.email_changeset(%{email: email})
      |> AuthUser.confirm_changeset()

    Ecto.Multi.new()
    |> Ecto.Multi.update(:auth_user, changeset)
    |> Ecto.Multi.delete_all(:tokens, AuthUserToken.auth_user_and_contexts_query(auth_user, [context]))
  end

  @doc """
  Delivers the update email instructions to the given auth_user.

  ## Examples

      iex> deliver_update_email_instructions(auth_user, current_email, &Routes.auth_user_update_email_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_update_email_instructions(%AuthUser{} = auth_user, current_email, update_email_url_fun)
      when is_function(update_email_url_fun, 1) do
    {encoded_token, auth_user_token} = AuthUserToken.build_email_token(auth_user, "change:#{current_email}")

    Repo.insert!(auth_user_token)
    AuthUserNotifier.deliver_update_email_instructions(auth_user, update_email_url_fun.(encoded_token))
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the auth_user password.

  ## Examples

      iex> change_auth_user_password(auth_user)
      %Ecto.Changeset{data: %AuthUser{}}

  """
  def change_auth_user_password(auth_user, attrs \\ %{}) do
    AuthUser.password_changeset(auth_user, attrs, hash_password: false)
  end

  @doc """
  Updates the auth_user password.

  ## Examples

      iex> update_auth_user_password(auth_user, "valid password", %{password: ...})
      {:ok, %AuthUser{}}

      iex> update_auth_user_password(auth_user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_auth_user_password(auth_user, password, attrs) do
    changeset =
      auth_user
      |> AuthUser.password_changeset(attrs)
      |> AuthUser.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:auth_user, changeset)
    |> Ecto.Multi.delete_all(:tokens, AuthUserToken.auth_user_and_contexts_query(auth_user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{auth_user: auth_user}} -> {:ok, auth_user}
      {:error, :auth_user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_auth_user_session_token(auth_user) do
    {token, auth_user_token} = AuthUserToken.build_session_token(auth_user)
    Repo.insert!(auth_user_token)
    token
  end

  @doc """
  Gets the auth_user with the given signed token.
  """
  def get_auth_user_by_session_token(token) do
    {:ok, query} = AuthUserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_session_token(token) do
    Repo.delete_all(AuthUserToken.token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc """
  Delivers the confirmation email instructions to the given auth_user.

  ## Examples

      iex> deliver_auth_user_confirmation_instructions(auth_user, &Routes.auth_user_confirmation_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

      iex> deliver_auth_user_confirmation_instructions(confirmed_auth_user, &Routes.auth_user_confirmation_url(conn, :edit, &1))
      {:error, :already_confirmed}

  """
  def deliver_auth_user_confirmation_instructions(%AuthUser{} = auth_user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if auth_user.confirmed_at do
      {:error, :already_confirmed}
    else
      {encoded_token, auth_user_token} = AuthUserToken.build_email_token(auth_user, "confirm")
      Repo.insert!(auth_user_token)
      AuthUserNotifier.deliver_confirmation_instructions(auth_user, confirmation_url_fun.(encoded_token))
    end
  end

  @doc """
  Confirms a auth_user by the given token.

  If the token matches, the auth_user account is marked as confirmed
  and the token is deleted.
  """
  def confirm_auth_user(token) do
    with {:ok, query} <- AuthUserToken.verify_email_token_query(token, "confirm"),
         %AuthUser{} = auth_user <- Repo.one(query),
         {:ok, %{auth_user: auth_user}} <- Repo.transaction(confirm_auth_user_multi(auth_user)) do
      {:ok, auth_user}
    else
      _ -> :error
    end
  end

  defp confirm_auth_user_multi(auth_user) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:auth_user, AuthUser.confirm_changeset(auth_user))
    |> Ecto.Multi.delete_all(:tokens, AuthUserToken.auth_user_and_contexts_query(auth_user, ["confirm"]))
  end

  ## Reset password

  @doc """
  Delivers the reset password email to the given auth_user.

  ## Examples

      iex> deliver_auth_user_reset_password_instructions(auth_user, &Routes.auth_user_reset_password_url(conn, :edit, &1))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_auth_user_reset_password_instructions(%AuthUser{} = auth_user, reset_password_url_fun)
      when is_function(reset_password_url_fun, 1) do
    {encoded_token, auth_user_token} = AuthUserToken.build_email_token(auth_user, "reset_password")
    Repo.insert!(auth_user_token)
    AuthUserNotifier.deliver_reset_password_instructions(auth_user, reset_password_url_fun.(encoded_token))
  end

  @doc """
  Gets the auth_user by reset password token.

  ## Examples

      iex> get_auth_user_by_reset_password_token("validtoken")
      %AuthUser{}

      iex> get_auth_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_auth_user_by_reset_password_token(token) do
    with {:ok, query} <- AuthUserToken.verify_email_token_query(token, "reset_password"),
         %AuthUser{} = auth_user <- Repo.one(query) do
      auth_user
    else
      _ -> nil
    end
  end

  @doc """
  Resets the auth_user password.

  ## Examples

      iex> reset_auth_user_password(auth_user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %AuthUser{}}

      iex> reset_auth_user_password(auth_user, %{password: "valid", password_confirmation: "not the same"})
      {:error, %Ecto.Changeset{}}

  """
  def reset_auth_user_password(auth_user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:auth_user, AuthUser.password_changeset(auth_user, attrs))
    |> Ecto.Multi.delete_all(:tokens, AuthUserToken.auth_user_and_contexts_query(auth_user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{auth_user: auth_user}} -> {:ok, auth_user}
      {:error, :auth_user, changeset, _} -> {:error, changeset}
    end
  end
end
