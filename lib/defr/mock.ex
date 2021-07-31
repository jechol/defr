defmodule Defr.Mock do
  @moduledoc false

  def decorate_with_fn({{:&, _, [{:/, _, [_mf, a]}]} = capture, v}) do
    const_fn = {:fn, [], [{:->, [], [Macro.generate_arguments(a, __MODULE__), v]}]}
    {capture, const_fn}
  end
end
