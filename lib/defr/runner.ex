defmodule MagicWand.Runner do
  alias Algae.State

  def run({m, f, a}, args, input) do
    {{m, f, a}, args, input}
    fun = :erlang.make_fun(m, f, a)
    ret = Map.get(input, fun, fun) |> :erlang.apply(args)

    case ret do
      %State{} = state ->
        {value, new_output} = state |> MagicWand.run(input)
        MagicWand.tell(new_output)
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
