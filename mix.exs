defmodule Tyrex.MixProject do
  use Mix.Project

  def project do
    [
      app: :tyrex,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      name: "Tyrex",
      source_url: "https://github.com/elias-ba/tyrex"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Tyrex.Application, []}
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:benchee, "~> 1.1", only: :dev},
      {:statistics, "~> 0.6"},
      # For JSON serialization
      {:poison, "~> 5.0"},
      # For neural network operations, optional
      {:nx, "~> 0.5", optional: true}
    ]
  end

  defp description do
    """
    Tyrex is a comprehensive genetic programming and neuroevolution library for Elixir.
    It provides implementations of standard genetic algorithms as well as the NEAT
    (NeuroEvolution of Augmenting Topologies) algorithm.
    """
  end

  defp package do
    [
      name: "tyrex",
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/elias-ba/tyrex"}
    ]
  end
end
