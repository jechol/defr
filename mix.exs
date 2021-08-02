defmodule MagicWand.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :magic_wand,
      version: @version,
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      package: package(),
      description: "Helper for Witchcraft's Reader monad",
      source_url: "https://github.com/trevorite/magic_wand",
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.23.0", only: :dev, runtime: false},
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}

      {:algae, "~> 1.3"}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/trevorite/magic_wand"},
      maintainers: ["Jechol Lee(mr.trevorite@gmail.com)"]
    ]
  end

  defp docs() do
    [
      main: "readme",
      name: "magic_wand",
      canonical: "http://hexdocs.pm/magic_wand",
      source_url: "https://github.com/trevorite/magic_wand",
      extras: [
        "README.md"
      ]
    ]
  end
end
