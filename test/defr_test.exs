defmodule DefrTest do
  use ExUnit.Case, async: true
  use Defr
  alias Algae.State

  defmodule Nested do
    defmodule DoubleNested do
      defdelegate to_int(str), to: String, as: :to_integer
      defdelegate to_atom(str), to: String, as: :to_atom
    end
  end

  alias Nested.DoubleNested

  describe "defr" do
    def quack(), do: nil

    defmodule Foo do
      use Defr
      import List, only: [first: 1]
      require Calc

      def quack(), do: :arity_0_quack
      def quack(_), do: :arity_1_quack

      def id(v), do: v

      defr bar(type) when is_atom(type) do
        case type do
          # Remote
          :mod -> __MODULE__.quack()
          :remote -> Enum.count([1, 2])
          :nested_remote -> {DoubleNested.to_int("99"), DoubleNested.to_atom("hello")}
          :pipe -> "1" |> Foo.id()
          :macro -> Calc.macro_sum(10, 20)
          :capture -> &Calc.sum/2
          :kernel_plus -> Kernel.+(1, 10)
          :string_to_atom -> "foobar" |> String.to_atom()
          :string_to_integer -> "100" |> String.to_integer()
          # Local, Import
          :local -> quack()
          :import -> first([10, 20])
          :anonymous_fun -> [1, 2] |> Enum.map(&Calc.id(&1))
          :string_concat -> "#{[1, 2] |> Enum.map(&"*#{&1}*") |> Enum.join()}"
        end
      end

      defr hash(<<data::binary>>) do
        :crypto.hash(:md5, <<data::binary>>)
      end
    end

    test "original works" do
      assert Foo.bar(:mod) |> State.run(%{}) == :arity_0_quack
      assert Foo.bar(:remote) |> State.run(%{}) == 2
      assert Foo.bar(:nested_remote) |> State.run(%{}) == {99, :hello}
      assert Foo.bar(:pipe) |> State.run(%{}) == "1"
      assert Foo.bar(:macro) |> State.run(%{}) == 30
      assert (Foo.bar(:capture) |> State.run(%{})).(20, 40) == 60
      assert Foo.bar(:kernel_plus) |> State.run(%{}) == 11
      assert Foo.bar(:string_to_atom) |> State.run(%{}) == :foobar
      assert Foo.bar(:string_to_integer) |> State.run(%{}) == 100

      assert Foo.bar(:local) |> State.run(%{}) == :arity_0_quack
      assert Foo.bar(:import) |> State.run(%{}) == 10
      assert Foo.bar(:anonymous_fun) |> State.run(%{}) == [1, 2]
      assert Foo.bar(:string_concat) |> State.run(%{}) == "*1**2*"

      assert Foo.hash("hello") |> State.run(%{}) ==
               <<93, 65, 64, 42, 188, 75, 42, 118, 185, 113, 157, 145, 16, 23, 197, 146>>
    end

    defmodule Baz do
      def quack, do: "baz quack"
      def to_int(_), do: "baz to_int"
      def to_atom(_), do: "baz to_atom"
    end

    test "working case" do
      assert Foo.bar(:mod) |> State.run(%{&Foo.quack/0 => fn -> :injected end}) ==
               :injected

      assert Foo.bar(:remote) |> State.run(%{&Enum.count/1 => fn _ -> 9999 end}) ==
               9999

      assert Foo.bar(:nested_remote)
             |> State.run(%{
               &DoubleNested.to_int/1 => &Baz.to_int/1,
               &DoubleNested.to_atom/1 => &Baz.to_atom/1
             }) == {"baz to_int", "baz to_atom"}

      assert Foo.bar(:nested_remote)
             |> State.run(mock(%{&DoubleNested.to_atom/1 => :mocked})) ==
               {99, :mocked}

      assert Foo.bar(:pipe)
             |> State.run(%{&Foo.id/1 => fn _ -> "100" end, &Enum.count/1 => fn _ -> 9999 end}) ==
               "100"

      assert Foo.bar(:macro) |> State.run(%{&Calc.sum/2 => fn _, _ -> 999 end}) ==
               30

      assert Foo.bar(:string_to_atom) |> State.run(%{&String.to_atom/1 => fn _ -> :injected end}) ==
               :injected

      assert Foo.hash("hello") |> State.run(%{&:crypto.hash/2 => fn _, _ -> :world end}) ==
               :world
    end
  end

  test "mock" do
    m = mock(%{&Enum.count/1 => (fn -> 100 end).(), &Enum.map/2 => 200})

    f1 = m[&Enum.count/1]
    f2 = m[&Enum.map/2]

    assert :erlang.fun_info(f1)[:arity] == 1
    assert :erlang.fun_info(f2)[:arity] == 2

    assert f1.(nil) == 100
    assert f2.(nil, nil) == 200
  end
end
