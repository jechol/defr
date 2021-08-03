defmodule MagicWand.TellTest do
  use ExUnit.Case, async: true
  use MagicWand
  alias Algae.State
  alias Algae.Either.Right
  require Logger

  defmodule SMTPClient do
    defr send_welcome(email) do
      :ok |> Right.new()
    end
  end

  defmodule User do
    use MagicWand

    defstruct [:email]

    defr create_user(email) do
      %__MODULE__{email: email}
      |> Right.new()
      |> MagicWand.result({&IO.puts/1, "user created"})
    end
  end

  defmodule Accounts do
    use MagicWand

    defr sign_up(email) do
      monad %Right{} do
        user <- User.create_user(email) |> IO.inspect(label: "either")

        MagicWand.result(user |> Right.new(), {&SMTPClient.send_welcome/1, email})
      end
    end
  end

  test "User.create_user" do
    assert %Result{
             val: %Right{right: %User{email: "test@gmail.com"}},
             output: [{&IO.puts/1, "user created"}]
           } == User.create_user("test@gmail.com") |> MagicWand.run(%{})
  end

  test "User.create_user call_fun" do
    assert %Result{
             val: %Right{right: %User{email: "test@gmail.com"}},
             output: [{&IO.puts/1, "user created"}]
           } == MagicWand.Runner.call_fun({User, :create_user, 1}, ["test@gmail.com"], %{})
  end

  test "Accounts.result" do
    assert %Result{
             val: %Right{right: %User{email: "test@gmail.com"}},
             output: [
               {&IO.puts/1, "user created"},
               {&SMTPClient.send_welcome/1, "test@gmail.com"}
             ]
           } == Accounts.sign_up("test1@gmail.com") |> MagicWand.run(%{})
  end
end
