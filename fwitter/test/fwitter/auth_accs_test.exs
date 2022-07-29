defmodule Fwitter.AuthAccsTest do
  use Fwitter.DataCase

  alias Fwitter.AuthAccs

  import Fwitter.AuthAccsFixtures
  alias Fwitter.AuthAccs.{AuthUser, AuthUserToken}

  describe "get_auth_user_by_email/1" do
    test "does not return the auth_user if the email does not exist" do
      refute AuthAccs.get_auth_user_by_email("unknown@example.com")
    end

    test "returns the auth_user if the email exists" do
      %{id: id} = auth_user = auth_user_fixture()
      assert %AuthUser{id: ^id} = AuthAccs.get_auth_user_by_email(auth_user.email)
    end
  end

  describe "get_auth_user_by_email_and_password/2" do
    test "does not return the auth_user if the email does not exist" do
      refute AuthAccs.get_auth_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the auth_user if the password is not valid" do
      auth_user = auth_user_fixture()
      refute AuthAccs.get_auth_user_by_email_and_password(auth_user.email, "invalid")
    end

    test "returns the auth_user if the email and password are valid" do
      %{id: id} = auth_user = auth_user_fixture()

      assert %AuthUser{id: ^id} =
               AuthAccs.get_auth_user_by_email_and_password(auth_user.email, valid_auth_user_password())
    end
  end

  describe "get_auth_user!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        AuthAccs.get_auth_user!(-1)
      end
    end

    test "returns the auth_user with the given id" do
      %{id: id} = auth_user = auth_user_fixture()
      assert %AuthUser{id: ^id} = AuthAccs.get_auth_user!(auth_user.id)
    end
  end

  describe "register_auth_user/1" do
    test "requires email and password to be set" do
      {:error, changeset} = AuthAccs.register_auth_user(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = AuthAccs.register_auth_user(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = AuthAccs.register_auth_user(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = auth_user_fixture()
      {:error, changeset} = AuthAccs.register_auth_user(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = AuthAccs.register_auth_user(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers auth_users with a hashed password" do
      email = unique_auth_user_email()
      {:ok, auth_user} = AuthAccs.register_auth_user(valid_auth_user_attributes(email: email))
      assert auth_user.email == email
      assert is_binary(auth_user.hashed_password)
      assert is_nil(auth_user.confirmed_at)
      assert is_nil(auth_user.password)
    end
  end

  describe "change_auth_user_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = AuthAccs.change_auth_user_registration(%AuthUser{})
      assert changeset.required == [:password, :email]
    end

    test "allows fields to be set" do
      email = unique_auth_user_email()
      password = valid_auth_user_password()

      changeset =
        AuthAccs.change_auth_user_registration(
          %AuthUser{},
          valid_auth_user_attributes(email: email, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "change_auth_user_email/2" do
    test "returns a auth_user changeset" do
      assert %Ecto.Changeset{} = changeset = AuthAccs.change_auth_user_email(%AuthUser{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_auth_user_email/3" do
    setup do
      %{auth_user: auth_user_fixture()}
    end

    test "requires email to change", %{auth_user: auth_user} do
      {:error, changeset} = AuthAccs.apply_auth_user_email(auth_user, valid_auth_user_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{auth_user: auth_user} do
      {:error, changeset} =
        AuthAccs.apply_auth_user_email(auth_user, valid_auth_user_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{auth_user: auth_user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        AuthAccs.apply_auth_user_email(auth_user, valid_auth_user_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{auth_user: auth_user} do
      %{email: email} = auth_user_fixture()

      {:error, changeset} =
        AuthAccs.apply_auth_user_email(auth_user, valid_auth_user_password(), %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{auth_user: auth_user} do
      {:error, changeset} =
        AuthAccs.apply_auth_user_email(auth_user, "invalid", %{email: unique_auth_user_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{auth_user: auth_user} do
      email = unique_auth_user_email()
      {:ok, auth_user} = AuthAccs.apply_auth_user_email(auth_user, valid_auth_user_password(), %{email: email})
      assert auth_user.email == email
      assert AuthAccs.get_auth_user!(auth_user.id).email != email
    end
  end

  describe "deliver_update_email_instructions/3" do
    setup do
      %{auth_user: auth_user_fixture()}
    end

    test "sends token through notification", %{auth_user: auth_user} do
      token =
        extract_auth_user_token(fn url ->
          AuthAccs.deliver_update_email_instructions(auth_user, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert auth_user_token = Repo.get_by(AuthUserToken, token: :crypto.hash(:sha256, token))
      assert auth_user_token.auth_user_id == auth_user.id
      assert auth_user_token.sent_to == auth_user.email
      assert auth_user_token.context == "change:current@example.com"
    end
  end

  describe "update_auth_user_email/2" do
    setup do
      auth_user = auth_user_fixture()
      email = unique_auth_user_email()

      token =
        extract_auth_user_token(fn url ->
          AuthAccs.deliver_update_email_instructions(%{auth_user | email: email}, auth_user.email, url)
        end)

      %{auth_user: auth_user, token: token, email: email}
    end

    test "updates the email with a valid token", %{auth_user: auth_user, token: token, email: email} do
      assert AuthAccs.update_auth_user_email(auth_user, token) == :ok
      changed_auth_user = Repo.get!(AuthUser, auth_user.id)
      assert changed_auth_user.email != auth_user.email
      assert changed_auth_user.email == email
      assert changed_auth_user.confirmed_at
      assert changed_auth_user.confirmed_at != auth_user.confirmed_at
      refute Repo.get_by(AuthUserToken, auth_user_id: auth_user.id)
    end

    test "does not update email with invalid token", %{auth_user: auth_user} do
      assert AuthAccs.update_auth_user_email(auth_user, "oops") == :error
      assert Repo.get!(AuthUser, auth_user.id).email == auth_user.email
      assert Repo.get_by(AuthUserToken, auth_user_id: auth_user.id)
    end

    test "does not update email if auth_user email changed", %{auth_user: auth_user, token: token} do
      assert AuthAccs.update_auth_user_email(%{auth_user | email: "current@example.com"}, token) == :error
      assert Repo.get!(AuthUser, auth_user.id).email == auth_user.email
      assert Repo.get_by(AuthUserToken, auth_user_id: auth_user.id)
    end

    test "does not update email if token expired", %{auth_user: auth_user, token: token} do
      {1, nil} = Repo.update_all(AuthUserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert AuthAccs.update_auth_user_email(auth_user, token) == :error
      assert Repo.get!(AuthUser, auth_user.id).email == auth_user.email
      assert Repo.get_by(AuthUserToken, auth_user_id: auth_user.id)
    end
  end

  describe "change_auth_user_password/2" do
    test "returns a auth_user changeset" do
      assert %Ecto.Changeset{} = changeset = AuthAccs.change_auth_user_password(%AuthUser{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        AuthAccs.change_auth_user_password(%AuthUser{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_auth_user_password/3" do
    setup do
      %{auth_user: auth_user_fixture()}
    end

    test "validates password", %{auth_user: auth_user} do
      {:error, changeset} =
        AuthAccs.update_auth_user_password(auth_user, valid_auth_user_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{auth_user: auth_user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        AuthAccs.update_auth_user_password(auth_user, valid_auth_user_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{auth_user: auth_user} do
      {:error, changeset} =
        AuthAccs.update_auth_user_password(auth_user, "invalid", %{password: valid_auth_user_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{auth_user: auth_user} do
      {:ok, auth_user} =
        AuthAccs.update_auth_user_password(auth_user, valid_auth_user_password(), %{
          password: "new valid password"
        })

      assert is_nil(auth_user.password)
      assert AuthAccs.get_auth_user_by_email_and_password(auth_user.email, "new valid password")
    end

    test "deletes all tokens for the given auth_user", %{auth_user: auth_user} do
      _ = AuthAccs.generate_auth_user_session_token(auth_user)

      {:ok, _} =
        AuthAccs.update_auth_user_password(auth_user, valid_auth_user_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(AuthUserToken, auth_user_id: auth_user.id)
    end
  end

  describe "generate_auth_user_session_token/1" do
    setup do
      %{auth_user: auth_user_fixture()}
    end

    test "generates a token", %{auth_user: auth_user} do
      token = AuthAccs.generate_auth_user_session_token(auth_user)
      assert auth_user_token = Repo.get_by(AuthUserToken, token: token)
      assert auth_user_token.context == "session"

      # Creating the same token for another auth_user should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%AuthUserToken{
          token: auth_user_token.token,
          auth_user_id: auth_user_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_auth_user_by_session_token/1" do
    setup do
      auth_user = auth_user_fixture()
      token = AuthAccs.generate_auth_user_session_token(auth_user)
      %{auth_user: auth_user, token: token}
    end

    test "returns auth_user by token", %{auth_user: auth_user, token: token} do
      assert session_auth_user = AuthAccs.get_auth_user_by_session_token(token)
      assert session_auth_user.id == auth_user.id
    end

    test "does not return auth_user for invalid token" do
      refute AuthAccs.get_auth_user_by_session_token("oops")
    end

    test "does not return auth_user for expired token", %{token: token} do
      {1, nil} = Repo.update_all(AuthUserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute AuthAccs.get_auth_user_by_session_token(token)
    end
  end

  describe "delete_session_token/1" do
    test "deletes the token" do
      auth_user = auth_user_fixture()
      token = AuthAccs.generate_auth_user_session_token(auth_user)
      assert AuthAccs.delete_session_token(token) == :ok
      refute AuthAccs.get_auth_user_by_session_token(token)
    end
  end

  describe "deliver_auth_user_confirmation_instructions/2" do
    setup do
      %{auth_user: auth_user_fixture()}
    end

    test "sends token through notification", %{auth_user: auth_user} do
      token =
        extract_auth_user_token(fn url ->
          AuthAccs.deliver_auth_user_confirmation_instructions(auth_user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert auth_user_token = Repo.get_by(AuthUserToken, token: :crypto.hash(:sha256, token))
      assert auth_user_token.auth_user_id == auth_user.id
      assert auth_user_token.sent_to == auth_user.email
      assert auth_user_token.context == "confirm"
    end
  end

  describe "confirm_auth_user/1" do
    setup do
      auth_user = auth_user_fixture()

      token =
        extract_auth_user_token(fn url ->
          AuthAccs.deliver_auth_user_confirmation_instructions(auth_user, url)
        end)

      %{auth_user: auth_user, token: token}
    end

    test "confirms the email with a valid token", %{auth_user: auth_user, token: token} do
      assert {:ok, confirmed_auth_user} = AuthAccs.confirm_auth_user(token)
      assert confirmed_auth_user.confirmed_at
      assert confirmed_auth_user.confirmed_at != auth_user.confirmed_at
      assert Repo.get!(AuthUser, auth_user.id).confirmed_at
      refute Repo.get_by(AuthUserToken, auth_user_id: auth_user.id)
    end

    test "does not confirm with invalid token", %{auth_user: auth_user} do
      assert AuthAccs.confirm_auth_user("oops") == :error
      refute Repo.get!(AuthUser, auth_user.id).confirmed_at
      assert Repo.get_by(AuthUserToken, auth_user_id: auth_user.id)
    end

    test "does not confirm email if token expired", %{auth_user: auth_user, token: token} do
      {1, nil} = Repo.update_all(AuthUserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert AuthAccs.confirm_auth_user(token) == :error
      refute Repo.get!(AuthUser, auth_user.id).confirmed_at
      assert Repo.get_by(AuthUserToken, auth_user_id: auth_user.id)
    end
  end

  describe "deliver_auth_user_reset_password_instructions/2" do
    setup do
      %{auth_user: auth_user_fixture()}
    end

    test "sends token through notification", %{auth_user: auth_user} do
      token =
        extract_auth_user_token(fn url ->
          AuthAccs.deliver_auth_user_reset_password_instructions(auth_user, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert auth_user_token = Repo.get_by(AuthUserToken, token: :crypto.hash(:sha256, token))
      assert auth_user_token.auth_user_id == auth_user.id
      assert auth_user_token.sent_to == auth_user.email
      assert auth_user_token.context == "reset_password"
    end
  end

  describe "get_auth_user_by_reset_password_token/1" do
    setup do
      auth_user = auth_user_fixture()

      token =
        extract_auth_user_token(fn url ->
          AuthAccs.deliver_auth_user_reset_password_instructions(auth_user, url)
        end)

      %{auth_user: auth_user, token: token}
    end

    test "returns the auth_user with valid token", %{auth_user: %{id: id}, token: token} do
      assert %AuthUser{id: ^id} = AuthAccs.get_auth_user_by_reset_password_token(token)
      assert Repo.get_by(AuthUserToken, auth_user_id: id)
    end

    test "does not return the auth_user with invalid token", %{auth_user: auth_user} do
      refute AuthAccs.get_auth_user_by_reset_password_token("oops")
      assert Repo.get_by(AuthUserToken, auth_user_id: auth_user.id)
    end

    test "does not return the auth_user if token expired", %{auth_user: auth_user, token: token} do
      {1, nil} = Repo.update_all(AuthUserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute AuthAccs.get_auth_user_by_reset_password_token(token)
      assert Repo.get_by(AuthUserToken, auth_user_id: auth_user.id)
    end
  end

  describe "reset_auth_user_password/2" do
    setup do
      %{auth_user: auth_user_fixture()}
    end

    test "validates password", %{auth_user: auth_user} do
      {:error, changeset} =
        AuthAccs.reset_auth_user_password(auth_user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{auth_user: auth_user} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = AuthAccs.reset_auth_user_password(auth_user, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{auth_user: auth_user} do
      {:ok, updated_auth_user} = AuthAccs.reset_auth_user_password(auth_user, %{password: "new valid password"})
      assert is_nil(updated_auth_user.password)
      assert AuthAccs.get_auth_user_by_email_and_password(auth_user.email, "new valid password")
    end

    test "deletes all tokens for the given auth_user", %{auth_user: auth_user} do
      _ = AuthAccs.generate_auth_user_session_token(auth_user)
      {:ok, _} = AuthAccs.reset_auth_user_password(auth_user, %{password: "new valid password"})
      refute Repo.get_by(AuthUserToken, auth_user_id: auth_user.id)
    end
  end

  describe "inspect/2" do
    test "does not include password" do
      refute inspect(%AuthUser{password: "123456"}) =~ "password: \"123456\""
    end
  end
end
