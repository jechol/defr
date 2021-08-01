defmodule Defr.Mock do
  @moduledoc false
  alias Algae.State

  def decorate_with_fn({{:&, _, [{:/, _, [{{:., _, [m, f]}, _, []}, a]}]} = capture, v}) do
    unused_args = Macro.generate_arguments(a, __MODULE__)
    const_fn = {:fn, [], [{:->, [], [unused_args, v]}]}

    state =
      quote do
        State.new(fn state -> {unquote(v), state} end)
      end

    const_state_fn = {:fn, [], [{:->, [], [unused_args, state]}]}

    value =
      quote do
        Defr.Mock.wrap_if_reader(
          {unquote(m), unquote(f), unquote(a)},
          unquote(const_fn),
          unquote(const_state_fn)
        )
      end

    {capture, value}
  end

  def wrap_if_reader({m, f, a}, const_fn, const_state_fn) do
    if Defr.Runner.is_defr_fun?({m, f, a}) do
      const_state_fn
    else
      const_fn
    end
  end
end
