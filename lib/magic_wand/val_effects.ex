defmodule MagicWand.ValOutput do
  defstruct val: nil, output: []

  def new(val, output) when is_list(output) do
    %__MODULE__{val: val, output: output}
  end

  def new(val, output) do
    new(val, [output])
  end
end
