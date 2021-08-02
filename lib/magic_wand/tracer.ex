defmodule MagicWand.Tracer do
  @moduledoc false

  def trace(injected, original, %Macro.Env{file: file, line: line}) do
    if Application.get_env(:defr, :trace, false) do
      dash = "=============================="

      IO.puts("""

      #{dash} defr #{file}:#{line} #{dash}
      #{original |> Macro.to_string()}
      #{dash} into #{dash}"
      #{injected |> Macro.to_string()}

      """)
    end

    injected
  end
end
