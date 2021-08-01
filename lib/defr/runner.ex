defmodule Defr.Runner do
  alias Defr.InOut
  alias Algae.State

  def run({m, f, a}, args, input) do
    fun = :erlang.make_fun(m, f, a)
    ret = Map.get(input, fun, fun) |> :erlang.apply(args)

    case ret do
      %State{} = state ->
        {value, %InOut{input: input, output: new_output}} = state |> State.run(input)

        State.modify(fn %InOut{input: ^input, output: output} ->
          %InOut{input: input, output: output ++ new_output}
        end)

        value

      value ->
        value
    end
  end

  def is_defr_fun?({m, f, a}) do
    Kernel.function_exported?(m, :__defr_funs__, 0) and
      {f, a} in Kernel.apply(m, :__defr_funs__, [])
  end
end
