defmodule Defre do
  @doc false
  defmacro __using__(_opts) do
    quote do
      import Kernel, except: [def: 1, def: 2]
      import Defre.Def, only: [def: 1, def: 2]
    end
  end

  @doc """
  `defre` transforms a function to accept a map where dependent functions and modules can be injected.

      import Defre

      defre send_welcome_email(user_id) do
        %{email: email} = Repo.get(User, user_id)

        welcome_email(to: email)
        |> Mailer.send()
      end

  is expanded into (simplified to understand)

      def send_welcome_email(user_id, deps \\\\ %{}) do
        %{email: email} =
          Map.get(deps, &Repo.get/2,
            :erlang.make_fun(Map.get(deps, Repo, Repo), :get, 2)
          ).(User, user_id)

        welcome_email(to: email)
        |> Map.get(deps, &Mailer.send/1,
            :erlang.make_fun(Map.get(deps, Mailer, Mailer), :send, 1)
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

  `defre` raises if the passed map includes a function or a module that's not used within the injected function.
  You can disable this by adding `strict: false` option.

      test "send_welcome_email with strict: false" do
        Accounts.send_welcome_email(100, %{
          &Repo.get/2 => fn User, 100 -> %User{email: "user100@gmail.com"} end,
          &Repo.all/1 => fn _ -> [%User{email: "user100@gmail.com"}] end, # Unused
          strict: false
        })
      end
  """
  defmacro defre(head, body \\ nil)

  defmacro defre(head, nil) do
    original =
      quote do
        def unquote(head)
      end

    do_definject(head, [], original, __CALLER__)
  end

  defmacro defre(head, body) do
    original =
      quote do
        def unquote(head), unquote(body)
      end

    do_definject(head, body, original, __CALLER__)
  end

  defp do_definject(head, body, original, %Macro.Env{} = env) do
    alias Defre.Inject

    if Application.get_env(:defre, :enable, Mix.env() == :test) do
      Inject.inject_function(head, body, env)
      |> trace(original, env)
    else
      original
    end
  end

  defp trace(injected, original, %Macro.Env{file: file, line: line}) do
    if Application.get_env(:defre, :trace, false) do
      dash = "=============================="

      IO.puts("""
      #{dash} defre #{file}:#{line} #{dash}
      #{original |> Macro.to_string()}
      #{dash} into #{dash}"
      #{injected |> Macro.to_string()}
      """)
    end

    injected
  end

  @doc """
  If you don't need pattern matching in mock function, `mock/1` can be used to reduce boilerplates.

      import Defre

      test "send_welcome_email with mock/1" do
        Accounts.send_welcome_email(
          100,
          mock(%{
            Repo => MockRepo,
            &Mailer.send/1 => Process.send(self(), :email_sent)
          })
        )

        assert_receive :email_sent
      end

  Note that `Process.send(self(), :email_sent)` is surrounded by `fn _ -> end` when expanded.
  """
  defmacro mock({:%{}, context, mocks}) do
    alias Defre.Mock

    {:%{}, context, mocks |> Enum.map(&Mock.decorate_with_fn/1)}
  end
end
