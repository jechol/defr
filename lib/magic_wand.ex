defmodule MagicWand do
  alias Algae.State

  defmodule InOut do
    defstruct input: %{}, output: []

    def new(%{} = input) do
      %__MODULE__{input: input, output: []}
    end
  end

  defmacro __using__(_) do
    quote do
      import MagicWand, only: :macros
      use Witchcraft.Monad
      alias MagicWand.InOut

      Module.register_attribute(__MODULE__, :defr_funs, accumulate: true)
      @before_compile unquote(MagicWand)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def __defr_funs__ do
        @defr_funs
      end
    end
  end

  def run(%State{} = state, %{} = input) do
    {value, %InOut{input: ^input, output: output}} = state |> State.run(%InOut{input: input})
    {value, output}
  end

  def tell(new_output) when is_list(new_output) do
    State.modify(fn %InOut{input: input, output: output} ->
      %InOut{input: input, output: output ++ new_output}
    end)
  end

  def tell(new_output), do: tell([new_output])

  @doc """
  `defr` transforms a function to accept a map where dependent functions and modules can be injected.

      use MagicWand

      defr send_welcome_email(user_id) do
        %{email: email} = Repo.get(User, user_id)

        welcome_email(to: email)
        |> Mailer.send()
      end

  is expanded into (simplified to understand)

      def send_welcome_email(user_id, input \\\\ %{}) do
        %{email: email} =
          Map.get(input, &Repo.get/2,
            :erlang.make_fun(Map.get(input, Repo, Repo), :get, 2)
          ).(User, user_id)

        welcome_email(to: email)
        |> Map.get(input, &Mailer.send/1,
            :erlang.make_fun(Map.get(input, Mailer, Mailer), :send, 1)
          ).()
      end

  Note that local function calls like `welcome_email(to: email)` are not expanded unless it is prepended with `__MODULE__`.

  Now, you can inject mock functions and modules in tests.

      test "send_welcome_email" do
        Accounts.send_welcome_email(100, %{
          Repo => MockRepo,
          &Mailer.send/1 => fn %Email{to: "user100@gmail.com", subject: "Welcome"} ->
            Process.send(self(), :email_sent)
          end
        })

        assert_receive :email_sent
      end

  `defr` raises if the passed map includes a function or a module that's not used within the injected function.
  You can disable this by adding `strict: false` option.

      test "send_welcome_email with strict: false" do
        Accounts.send_welcome_email(100, %{
          &Repo.get/2 => fn User, 100 -> %User{email: "user100@gmail.com"} end,
          &Repo.all/1 => fn _ -> [%User{email: "user100@gmail.com"}] end, # Unused
          strict: false
        })
      end
  """

  defmacro defr(head, body) do
    do_defr(:def, head, body, __CALLER__)
  end

  defp do_defr(def_type, head, body, env) do
    alias MagicWand.Inject

    original = {def_type, [context: Elixir, import: Kernel], [head, body]}

    Inject.inject_function(def_type, head, body, env)
    |> trace(original, env)
  end

  defp trace(injected, original, %Macro.Env{file: file, line: line}) do
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

  @doc """
  If you don't need pattern matching in mock function, `mock/1` can be used to reduce boilerplates.

      use MagicWand

      test "send_welcome_email with mock/1" do
        Accounts.send_welcome_email(100) |> Reader.run(
          mock(%{
            &Mailer.send/1 => Process.send(self(), :email_sent)
          })
        )

        assert_receive :email_sent
      end

  Note that `Process.send(self(), :email_sent)` is surrounded by `fn _ -> end` when expanded.
  """
  defmacro mock({:%{}, context, mocks}) do
    alias MagicWand.Mock

    {:%{}, context, mocks |> Enum.map(&Mock.decorate_with_fn/1)}
  end
end
