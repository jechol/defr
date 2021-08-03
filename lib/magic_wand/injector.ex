defmodule MagicWand.Injector do
  @moduledoc false

  alias MagicWand.AST

  @uninjectable [:erlang, Kernel, Kernel.Utils]
  @modifiers [:import, :require, :use]

  def inject_function(def_type, head, body, %Macro.Env{file: file, line: line} = env)
      when is_list(body) do
    inject_results =
      body
      |> Enum.map(fn
        {:do, blk} ->
          case blk |> inject_ast_recursively(env) do
            {:ok, injected_blk} ->
              {:do, injected_blk}

            {:error, :modifier} ->
              raise CompileError,
                file: file,
                line: line,
                description: "Cannot import/require/use inside defr. Move it to module level."
          end

        {key, blk} ->
          {key, blk}
      end)

    injected_body =
      inject_results
      |> Enum.reduce([], fn
        {:do, injected_blk}, acc ->
          do_blk =
            {:do,
             quote do
               use Witchcraft.Monad

               monad %Algae.State{runner: nil} do
                 %MagicWand.Token{input: input} <- Algae.State.get()

                 let %MagicWand.Result{val: val, output: output} =
                       unquote(injected_blk)
                       |> MagicWand.Runner.to_result()

                 MagicWand.tell(output)
                 return(val)
               end
             end}

          acc ++ [do_blk]

        {key, blk}, acc ->
          acc ++ [{key, blk}]
      end)

    fa = get_fa(head)
    definition = {def_type, [context: Elixir, import: Kernel], [head, injected_body]}

    case def_type do
      :def ->
        quote do
          @magic_funs unquote(fa)
          unquote(definition)
        end

      :defp ->
        definition
    end
  end

  defp get_fa({:when, _, [name_args, _when_cond]}) do
    get_fa(name_args)
  end

  defp get_fa({name, _, args}) when is_list(args) do
    {name, args |> Enum.count()}
  end

  defp get_fa({name, _, _}) do
    {name, 0}
  end

  def inject_ast_recursively(blk, env) do
    with {:ok, ^blk} <- blk |> check_no_modifier_recursively() do
      injected_blk =
        blk
        |> expand_recursively!(env)
        |> mark_remote_call_recursively!()
        |> Macro.postwalk(&inject/1)

      {:ok, injected_blk}
    end
  end

  defp check_no_modifier_recursively(ast) do
    case ast
         |> Macro.prewalk(:ok, fn
           _ast, {:error, :modifier} ->
             {nil, {:error, :modifier}}

           {modifier, _, _}, :ok when modifier in @modifiers ->
             {nil, {:error, :modifier}}

           ast, :ok ->
             {ast, :ok}
         end) do
      {expanded_ast, :ok} -> {:ok, expanded_ast}
      {_, {:error, :modifier}} -> {:error, :modifier}
    end
  end

  defp expand_recursively!(ast, env) do
    ast
    |> Macro.prewalk(fn
      {:@, _, _} = ast ->
        ast

      {:in, _, _} = ast ->
        ast

      ast ->
        Macro.expand(ast, env)
    end)
  end

  defp mark_remote_call_recursively!(ast) do
    ast
    |> Macro.prewalk(fn
      # capture
      {:&, c1, [{:/, c2, [mf, arity]}]} ->
        {:&, c1, [{:/, c2, [mf |> skip_inject(), arity]}]}

      # anonymous
      {:&, c1, [anonymous_fn]} ->
        {:&, c1, [anonymous_fn |> skip_inject()]}

      # rescue pattern matching
      {:->, c1, [left, right]} ->
        {:->, c1, [left |> Enum.map(&skip_inject/1), right]}

      ast ->
        ast
    end)
  end

  defp skip_inject({f, context, args}) when is_list(context) and is_list(args) do
    {f, [{:skip_inject, true} | context], args |> Enum.map(&skip_inject/1)}
  end

  defp skip_inject(ast) do
    ast
  end

  defp inject({_func, [{:skip_inject, true} | _], _args} = ast) do
    ast
  end

  defp inject({{:., _dot_ctx, [mod, name]}, _call_ctx, args} = ast)
       when is_atom(name) and is_list(args) do
    if AST.is_module_ast(mod) and AST.unquote_module_ast(mod) not in @uninjectable do
      arity = Enum.count(args)

      quote do
        MagicWand.Runner.call_fun(
          {unquote(mod), unquote(name), unquote(arity)},
          unquote(args),
          input
        )
      end
    else
      ast
    end
  end

  defp inject(ast) do
    ast
  end
end
