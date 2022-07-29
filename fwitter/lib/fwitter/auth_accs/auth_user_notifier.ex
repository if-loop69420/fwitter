defmodule Fwitter.AuthAccs.AuthUserNotifier do
  import Swoosh.Email

  alias Fwitter.Mailer

  # Delivers the email using the application mailer.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"Fwitter", "contact@example.com"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc """
  Deliver instructions to confirm account.
  """
  def deliver_confirmation_instructions(auth_user, url) do
    deliver(auth_user.email, "Confirmation instructions", """

    ==============================

    Hi #{auth_user.email},

    You can confirm your account by visiting the URL below:

    #{url}

    If you didn't create an account with us, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to reset a auth_user password.
  """
  def deliver_reset_password_instructions(auth_user, url) do
    deliver(auth_user.email, "Reset password instructions", """

    ==============================

    Hi #{auth_user.email},

    You can reset your password by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end

  @doc """
  Deliver instructions to update a auth_user email.
  """
  def deliver_update_email_instructions(auth_user, url) do
    deliver(auth_user.email, "Update email instructions", """

    ==============================

    Hi #{auth_user.email},

    You can change your email by visiting the URL below:

    #{url}

    If you didn't request this change, please ignore this.

    ==============================
    """)
  end
end
