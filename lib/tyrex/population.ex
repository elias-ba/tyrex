defmodule Tyrex.Population do
  @moduledoc """
  Functions for working with populations of individuals.
  """

  @doc """
  Creates a new population of individuals.

  ## Examples

      iex> Tyrex.Population.initialize(Tyrex.Genotypes.String, 100, length: 10)
  """
  def initialize(genotype_module, size, params \\ []) do
    for _ <- 1..size do
      genotype_module.create(params)
    end
  end

  @doc """
  Sorts a population by fitness in descending order.
  """
  def sort_by_fitness(population) do
    Enum.sort_by(population, & &1.fitness, :desc)
  end

  @doc """
  Returns the best individual in the population.
  """
  def best(population) do
    Enum.max_by(population, & &1.fitness)
  end

  @doc """
  Returns the average fitness of the population.
  """
  def average_fitness(population) do
    Enum.sum(Enum.map(population, & &1.fitness)) / length(population)
  end

  @doc """
  Returns the diversity of the population, based on the provided distance function.
  """
  def diversity(population, distance_fn) do
    sample_size = min(length(population), 20)
    sample = Enum.take_random(population, sample_size)

    pairs = for i <- sample, j <- sample, i != j, do: {i, j}

    if length(pairs) > 0 do
      pairs
      |> Enum.map(fn {i, j} -> distance_fn.(i, j) end)
      |> Enum.sum()
      |> Kernel./(length(pairs))
    else
      0.0
    end
  end
end
