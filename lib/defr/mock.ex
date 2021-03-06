defmodule Defr.Mock do
  @moduledoc false
  alias Algae.Reader

  def decorate_with_fn({{:&, _, [{:/, _, [{{:., _, [m, f]}, _, []}, a]}]} = capture, v}) do
    const_fn = {:fn, [], [{:->, [], [Macro.generate_arguments(a, __MODULE__), v]}]}

    reader_fn =
      {:fn, [],
       [
         {:->, [],
          [
            Macro.generate_arguments(a, __MODULE__),
            quote do
              Reader.new(fn _ask_ret -> unquote(v) end)
            end
          ]}
       ]}

    value =
      quote do
        {:module, unquote(m)} = Code.ensure_loaded(unquote(m))

        Defr.Mock.select(
          {unquote(m), unquote(f), unquote(a)},
          unquote(const_fn),
          unquote(reader_fn)
        )
      end

    {capture, value}
  end

  def decorate_with_fn({k, v}) do
    {k, v}
  end

  def select({m, f, a}, const_fn, reader_fn) do
    if is_defr_fun?({m, f, a}) do
      reader_fn
    else
      const_fn
    end
  end

  defp is_defr_fun?({m, f, a}) do
    Kernel.function_exported?(m, :__defr_funs__, 0) and
      {f, a} in Kernel.apply(m, :__defr_funs__, [])
  end
end
