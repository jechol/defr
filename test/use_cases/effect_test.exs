defmodule MagicWand.TellTest do
  use ExUnit.Case, async: true
  use MagicWand
  alias Algae.State
  alias Algae.Either.Right
  require Logger

  defmodule User do
    use MagicWand

    defstruct [:email]

    defr create_user(email) do
      %__MODULE__{email: email}
      |> Right.new()
      |> MagicWand.result({&IO.puts/1, "user created"})
    end
  end

  defmodule SMTPClient do
    defr send_welcome(email) do
      :ok |> Right.new()
    end
  end

  defmodule Accounts do
    use MagicWand

    defr sign_up(email) do
      chain do
        user <- User.create_user(email)

        MagicWand.result(user, {&SMTPClient.send_welcome/1, email})
      end
    end
  end

  test "create_user" do
    assert MagicWand.result(%User{email: "test@gmail.com"} |> Right.new(), [
             {&IO.puts/1, "user created"}
           ]) ==
             User.create_user("test@gmail.com") |> MagicWand.run(%{})
  end

  test "result" do
    Accounts.sign_up("test1@gmail.com") |> MagicWand.run(%{}) |> IO.inspect()
  end
end
