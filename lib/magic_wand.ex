defmodule MagicWand do
  alias MagicWand.{Token, Result, Tracer}
  alias Algae.State

  defmacro __using__(_) do
    quote do
      import MagicWand, only: [defr: 2, mock: 1, run: 2, tell: 1]
      use Witchcraft.Monad
      alias MagicWand.Result

      Module.register_attribute(__MODULE__, :magic_funs, accumulate: true)
      @before_compile unquote(MagicWand)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def __magic_funs__ do
        @magic_funs
      end
    end
  end

  defmacro defr(head, body) do
    do_defr(:def, head, body, __CALLER__)
  end

  defp do_defr(def_type, head, body, env) do
    alias MagicWand.Injector

    original = {def_type, [context: Elixir, import: Kernel], [head, body]}

    Injector.inject_function(def_type, head, body, env)
    |> Tracer.trace(original, env)
  end

  defmacro mock({:%{}, context, mocks}) do
    alias MagicWand.Mock

    {:%{}, context, mocks |> Enum.map(&Mock.decorate_with_fn/1)}
  end

  def run(%State{} = state, %{} = input) do
    {val, %Token{input: ^input, output: output}} =
      state |> State.run(%Token{input: input}) |> IO.inspect(label: "Wand.run")

    %Result{val: val, output: output}
  end

  def tell(new_output) when is_list(new_output) do
    State.modify(fn %Token{input: input, output: output} ->
      {output, new_output} |> IO.inspect(label: "MagicWand.tell")
      %Token{input: input, output: output ++ new_output}
    end)
  end

  def tell(new_output), do: tell([new_output])

  def result(val, output) do
    Result.new(val, output)
  end
end
