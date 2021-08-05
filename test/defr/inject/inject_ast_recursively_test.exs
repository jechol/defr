defmodule Defr.Inject.InjectAstRecursivelyTest do
  use ExUnit.Case, async: true
  require Defr.Inject
  alias Defr.Inject

  test "capture is not expanded" do
    blk =
      quote do
        &Calc.sum/2
      end

    assert {:ok, actual} = Inject.inject_ast_recursively(blk, __ENV__)
    assert Macro.to_string(blk) == Macro.to_string(actual)
  end

  test "access is not expanded" do
    blk =
      quote do
        conn.assigns
      end

    assert {:ok, actual} = Inject.inject_ast_recursively(blk, __ENV__)
    assert Macro.to_string(blk) == Macro.to_string(actual)
  end

  test ":erlang is not expanded" do
    blk =
      quote do
        :erlang.+(100, 200)
        Kernel.+(100, 200)
      end

    assert {:ok, actual} = Inject.inject_ast_recursively(blk, __ENV__)
    assert Macro.to_string(blk) == Macro.to_string(actual)
  end

  test "indirect import is allowed" do
    require Calc

    blk =
      quote do
        &Calc.sum/2
        Calc.macro_sum(10, 20)

        case 1 == 1 do
          x when x == true -> Math.pow(2, x)
        end
      end

    expected =
      quote do
        &Calc.sum/2

        (
          import(Calc)
          sum(10, 20)
        )

        case 1 == 1 do
          x when x == true ->
            Defr.Runner.call({Math, :pow, 2}, [2, x], deps)
        end
      end

    assert {:ok, actual} = Inject.inject_ast_recursively(blk, __ENV__)
    assert Macro.to_string(expected) == Macro.to_string(actual)
  end

  test "direct import is not allowed" do
    blk =
      quote do
        import Calc

        sum(a, b)
      end

    assert {:error, :modifier} = Inject.inject_ast_recursively(blk, __ENV__)
  end

  test "operator case 1" do
    blk =
      quote do
        Calc.to_int(a) >>> fn a_int -> Calc.to_int(b) >>> fn b_int -> a_int + b_int end end
      end

    expected =
      quote do
        Defr.Runner.call({Calc, :to_int, 1}, [a], deps) >>>
          fn a_int ->
            Defr.Runner.call({Calc, :to_int, 1}, [b], deps) >>> fn b_int -> a_int + b_int end
          end
      end

    assert {:ok, actual} = Inject.inject_ast_recursively(blk, __ENV__)
    assert Macro.to_string(expected) == Macro.to_string(actual)
  end

  test "operator case 2" do
    blk =
      quote do
        Calc.to_int(a) >>> fn a_int -> (fn b_int -> a_int + b_int end).(Calc.to_int(b)) end
      end

    expected =
      quote do
        Defr.Runner.call({Calc, :to_int, 1}, [a], deps) >>>
          fn a_int ->
            (fn b_int -> a_int + b_int end).(Defr.Runner.call({Calc, :to_int, 1}, [b], deps))
          end
      end

    assert {:ok, actual} = Inject.inject_ast_recursively(blk, __ENV__)
    assert Macro.to_string(expected) == Macro.to_string(actual)
  end

  test "try case 1" do
    blk =
      quote do
        try do
          Calc.id(:try)
        else
          x -> Calc.id(:else)
        rescue
          e in ArithmeticError -> Calc.id(e)
        catch
          :error, number -> Calc.id(number)
        end
      end

    expected =
      quote do
        try do
          Defr.Runner.call({Calc, :id, 1}, [:try], deps)
        rescue
          e in ArithmeticError ->
            Defr.Runner.call({Calc, :id, 1}, [e], deps)
        catch
          :error, number ->
            Defr.Runner.call({Calc, :id, 1}, [number], deps)
        else
          x ->
            Defr.Runner.call({Calc, :id, 1}, [:else], deps)
        end
      end

    assert {:ok, actual} = Inject.inject_ast_recursively(blk, __ENV__)
    assert Macro.to_string(expected) == Macro.to_string(actual)
  end
end
