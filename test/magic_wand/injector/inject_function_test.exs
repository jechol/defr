defmodule MagicWand.Injector.InjectFunctionTest do
  use ExUnit.Case, async: true
  require MagicWand.Injector
  alias MagicWand.Injector

  test "defr" do
    {:defr, _, [head, body]} =
      quote do
        defr add(a, b) do
          Calc.sum(a, b)
          Calc.macro_sum(a, b)
        end
      end

    expected =
      quote do
        @magic_funs {:add, 2}
        def add(a, b) do
          use Witchcraft.Monad

          monad %Algae.State{runner: nil} do
            %MagicWand.InputOutput{input: input} <- Algae.State.get()

            return(
              (
                MagicWand.Runner.call_fun({Calc, :sum, 2}, [a, b], input)

                (
                  import Calc
                  sum(a, b)
                )
              )
            )
          end
        end
      end

    actual = Injector.inject_function(:def, head, body, env_with_macros())
    assert Macro.to_string(expected) == Macro.to_string(actual)
  end

  test "modifier is not allowed" do
    assert_raise CompileError, ~r(import/require/use), fn ->
      Path.expand("../../support/import_in_inject.exs", __DIR__)
      |> Code.eval_file()
    end
  end

  defp env_with_macros do
    import Calc
    dummy_for_suppress_unused_warning()
    __ENV__
  end
end
