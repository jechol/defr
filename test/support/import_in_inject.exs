defmodule ImportInInject do
  use MagicWand

  defr str_to_atom(str) do
    import Calc
    to_int(str)
  end
end
