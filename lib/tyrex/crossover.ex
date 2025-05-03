defmodule Tyrex.Crossover do
  @moduledoc """
  Crossover operations for genetic algorithms.
  """

  @doc """
  Performs crossover on the population.

  ## Examples

      iex> Tyrex.Crossover.crossover(population, &Tyrex.Genotypes.String.crossover/2, 0.7)
  """
  def crossover(population, crossover_fn, rate) do
    pairs = Enum.chunk_every(population, 2)

    Enum.flat_map(pairs, fn
      [parent1, parent2] ->
        if :rand.uniform() < rate do
          crossover_fn.(parent1, parent2)
        else
          [parent1, parent2]
        end

      [single] ->
        [single]
    end)
  end

  @doc """
  Default implementation for single-point crossover.
  """
  def single_point(parent1, parent2, options \\ []) do
    point_fn = Keyword.get(options, :point_fn, &random_point/2)

    point = point_fn.(parent1, parent2)

    {parent1_head, parent1_tail} = Enum.split(parent1.genes, point)
    {parent2_head, parent2_tail} = Enum.split(parent2.genes, point)

    child1 = %{parent1 | genes: parent1_head ++ parent2_tail, fitness: 0}
    child2 = %{parent2 | genes: parent2_head ++ parent1_tail, fitness: 0}

    [child1, child2]
  end

  @doc """
  Default implementation for two-point crossover.
  """
  def two_point(parent1, parent2, options \\ []) do
    point_fn = Keyword.get(options, :point_fn, &random_points/2)

    [point1, point2] = point_fn.(parent1, parent2)

    [point1, point2] = Enum.sort([point1, point2])

    {parent1_head, parent1_rest} = Enum.split(parent1.genes, point1)
    {parent1_middle, parent1_tail} = Enum.split(parent1_rest, point2 - point1)

    {parent2_head, parent2_rest} = Enum.split(parent2.genes, point1)
    {parent2_middle, parent2_tail} = Enum.split(parent2_rest, point2 - point1)

    child1 = %{parent1 | genes: parent1_head ++ parent2_middle ++ parent1_tail, fitness: 0}
    child2 = %{parent2 | genes: parent2_head ++ parent1_middle ++ parent2_tail, fitness: 0}

    [child1, child2]
  end

  @doc """
  Default implementation for uniform crossover.
  """
  def uniform(parent1, parent2, options \\ []) do
    swap_rate = Keyword.get(options, :swap_rate, 0.5)

    min_length = min(length(parent1.genes), length(parent2.genes))

    child1_genes =
      for i <- 0..(min_length - 1) do
        if :rand.uniform() < swap_rate do
          Enum.at(parent2.genes, i)
        else
          Enum.at(parent1.genes, i)
        end
      end

    child2_genes =
      for i <- 0..(min_length - 1) do
        if :rand.uniform() < swap_rate do
          Enum.at(parent1.genes, i)
        else
          Enum.at(parent2.genes, i)
        end
      end

    child1 = %{parent1 | genes: child1_genes, fitness: 0}
    child2 = %{parent2 | genes: child2_genes, fitness: 0}

    [child1, child2]
  end

  defp random_point(parent1, parent2) do
    min_length = min(length(parent1.genes), length(parent2.genes))
    :rand.uniform(min_length - 1)
  end

  defp random_points(parent1, parent2) do
    min_length = min(length(parent1.genes), length(parent2.genes))

    if min_length <= 2 do
      [1, 1]
    else
      point1 = :rand.uniform(min_length - 2)
      point2 = point1 + :rand.uniform(min_length - point1 - 1)
      [point1, point2]
    end
  end
end
