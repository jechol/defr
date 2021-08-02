[![mix test](https://github.com/trevorite/magic_wand/workflows/mix%20test/badge.svg)](https://github.com/trevorite/magic_wand/actions)
[![Hex version badge](https://img.shields.io/hexpm/v/magic_wand.svg)](https://hex.pm/packages/magic_wand)
[![License badge](https://img.shields.io/hexpm/l/magic_wand.svg)](https://github.com/trevorite/magic_wand/blob/master/LICENSE.md)

`defr` is `def` for Witchcraft's Reader monads.

## Installation

The package can be installed by adding `magic_wand` to your list of dependencies
in `mix.exs`:

```elixir
def deps do
  [{:magic_wand, "~> 0.1"}]
end
```

To format `defr` like `def`, add following to your `.formatter.exs`

```elixir
locals_without_parens: [defr: 2]
```

## Usage

```elixir
defmodule MagicWand.NestedCallTest do
  use ExUnit.Case, async: true
  use MagicWand
  alias Algae.Reader
  alias Algae.Either.Right

  defmodule User do
    use MagicWand

    defstruct [:id, :name]

    defr get_by_id(user_id) do
      Repo.get(__MODULE__, user_id) |> Right.new()
    end
  end

  defmodule Accounts do
    use MagicWand

    defr get_user_by_id(user_id) do
      monad %Right{} do
        user <- User.get_by_id(user_id)
        user |> Right.new()
      end
    end
  end

  defmodule UserController do
    use MagicWand

    defr profile(user_id_str) do
      user_id = String.to_integer(user_id_str)
      Accounts.get_user_by_id(user_id)
    end
  end

  test "inject 3rd layer" do
    assert %Right{right: %User{id: 1, name: "josevalim"}} ==
             UserController.profile("1")
             |> Reader.run(%{&Repo.get/2 => fn _, _ -> %User{id: 1, name: "josevalim"} end})
  end

  test "inject 2nd layer" do
    assert %Right{right: %User{id: 2, name: "chrismccord"}} ==
             UserController.profile("2")
             |> Reader.run(%{
               &User.get_by_id/1 => fn _ ->
                 Reader.new(fn _ -> Right.new(%User{id: 2, name: "chrismccord"}) end)
               end
             })
  end
end
```

### mock

If you don't need pattern matching in mock function, `mock/1` can be used to reduce boilerplates.

```elixir
UserController.profile("1") |> Reader.run(%{&Repo.get/2 => fn _, _ -> %User{} end})
```

can be changed to

```elixir
UserController.profile("1") |> Reader.run(%{&Repo.get/2 => mock(%User{})})
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE.md) file for details
