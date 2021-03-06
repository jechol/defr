defmodule Defr.Rither do
  use Witchcraft
  alias __MODULE__
  alias Algae.Either.{Left, Right}
  import Algae

  defdata(fun())

  def new(fun), do: %Rither{rither: fun}
  def left(error), do: new(fn _ -> Left.new(error) end)
  def right(value), do: new(fn _ -> Right.new(value) end)

  def run(%Rither{rither: fun}, arg), do: fun.(arg)

  def ask(), do: Rither.new(fn env -> Right.new(env) end)

  def ask(fun) do
    monad %Rither{} do
      env <- ask()
      return(fun.(env))
    end
  end
end

alias Defr.Rither
alias Algae.Either.{Left, Right}
import TypeClass
use Witchcraft

definst Witchcraft.Functor, for: Rither do
  @force_type_instance true
  def map(%Rither{rither: inner}, fun) do
    Rither.new(fn env ->
      inner.(env) |> Witchcraft.Functor.map(fun)
    end)
  end
end

definst Witchcraft.Applicative, for: Rither do
  @force_type_instance true
  def of(_, value), do: Rither.right(value)
end

definst Witchcraft.Chain, for: Rither do
  @force_type_instance true
  alias Rither

  def chain(rither, link) do
    Rither.new(fn env ->
      case rither |> Rither.run(env) do
        %Left{} = left -> left
        %Right{right: value} -> link.(value) |> Rither.run(env)
      end
    end)
  end
end

definst Witchcraft.Monad, for: Rither do
  @force_type_instance true
end
