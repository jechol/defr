defmodule MagicWand.Runner do
  @moduledoc false

  alias Algae.State
  alias MagicWand.Result

  def call_fun({m, f, a}, args, input) do
    {{m, f, a}, args, input}
    fun = :erlang.make_fun(m, f, a)
    ret = Map.get(input, fun, fun) |> :erlang.apply(args)

    case ret do
      %State{} = state ->
        state |> MagicWand.run(input)

      val ->
        val
    end
  end

  def to_result(%Result{} = r), do: r |> IO.inspect(label: "skipped")
  def to_result(val), do: %Result{val: val, output: []}

  def is_defr_fun?({m, f, a}) do
    Kernel.function_exported?(m, :__magic_funs__, 0) and
      {f, a} in Kernel.apply(m, :__magic_funs__, [])
  end
end
