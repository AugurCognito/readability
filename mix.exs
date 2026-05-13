defmodule Readability.Mixfile do
  use Mix.Project

  @source_url "https://github.com/AugurCognito/readability"
  @version "0.13.0"

  def project do
    [
      app: :readability,
      version: @version,
      elixir: "~> 1.15",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      package: package(),
      deps: deps(),
      docs: docs()
    ]
  end

  def application do
    []
  end

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "test.watch": :test
      ]
    ]
  end

  defp deps do
    # https://github.com/lpil/mix-test.watch/pull/140#issuecomment-1853912030
    test_watch_runtime = match?(["test.watch" | _], System.argv())

    [
      {:lazy_html, ">= 0.1.0"},
      {:ex_doc, "~> 0.31", only: :dev},
      {:credo, "~> 1.7", only: [:dev, :test]},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:mix_test_watch, "~> 1.2", only: [:dev, :test], runtime: test_watch_runtime}
    ]
  end

  defp package do
    [
      description: "Readability library for extracting and curating articles.",
      files: ["lib", "mix.exs", "README*", "LICENSE*", "doc"],
      maintainers: ["Jaehyun Shin", "Jakub Skałecki", "Aniket Singh"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url
      }
    ]
  end

  defp docs do
    [
      extras: [
        "LICENSE.md": [title: "License"],
        "README.md": [title: "Overview"]
      ],
      main: "readme",
      source_url: @source_url,
      formatters: ["html"]
    ]
  end
end
