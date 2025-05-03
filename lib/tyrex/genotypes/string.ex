defmodule Tyrex.Genotypes.String do
  @moduledoc """
  String genotype for genetic algorithms.

  This genotype represents a string as a list of character codes.
  It's useful for problems like the "abracadabra" problem.
  """

  @doc """
  Creates a new individual with random genes.

  ## Options

  * `:length` - Length of the string (default: 10)
  * `:charset` - Character set to use (default: lowercase letters)
  """
  def create(opts \\ []) do
    length = Keyword.get(opts, :length, 10)
    charset = Keyword.get(opts, :charset, ?a..?z)

    genes =
      for _ <- 1..length do
        Enum.random(charset)
      end

    %{genes: genes, fitness: 0}
  end

  @doc """
  Initializes a population of string individuals.
  """
  def initialize(population_size, opts \\ []) do
    for _ <- 1..population_size do
      create(opts)
    end
  end

  @doc """
  Converts the genes to a string for display.
  """
  def to_string(individual) do
    List.to_string(individual.genes)
  end

  @doc """
  Creates an individual from a string.
  """
  def from_string(string) do
    genes = String.to_charlist(string)
    %{genes: genes, fitness: 0}
  end

  @doc """
  Performs crossover between two individuals.

  By default, uses single-point crossover.
  """
  def crossover(parent1, parent2, opts \\ []) do
    crossover_type = Keyword.get(opts, :type, :single_point)

    case crossover_type do
      :single_point ->
        Tyrex.Crossover.single_point(parent1, parent2, opts)

      :two_point ->
        Tyrex.Crossover.two_point(parent1, parent2, opts)

      :uniform ->
        Tyrex.Crossover.uniform(parent1, parent2, opts)

      _ ->
        Tyrex.Crossover.single_point(parent1, parent2, opts)
    end
  end

  @doc """
  Performs mutation on an individual.

  By default, uses point mutation with the lowercase alphabet.
  """
  def mutate(individual, opts \\ []) do
    mutation_type = Keyword.get(opts, :type, :point)
    charset = Keyword.get(opts, :charset, ?a..?z)
    options = Keyword.put(opts, :gene_pool, charset)

    case mutation_type do
      :point ->
        Tyrex.Mutation.point(individual, options)

      :swap ->
        Tyrex.Mutation.swap(individual, opts)

      :scramble ->
        Tyrex.Mutation.scramble(individual, opts)

      :inversion ->
        Tyrex.Mutation.inversion(individual, opts)

      :multi_point ->
        Tyrex.Mutation.multi_point(individual, options)

      _ ->
        Tyrex.Mutation.point(individual, options)
    end
  end

  @doc """
  Calculates the fitness of an individual for the string matching problem.

  Fitness is the number of characters that match the target string.
  """
  def string_match_fitness(individual, target) do
    target_chars = String.to_charlist(target)

    # Calculate how many characters match the target string
    Enum.zip(individual.genes, target_chars)
    |> Enum.count(fn {a, b} -> a == b end)
  end

  @doc """
  Measures the distance between two string individuals.

  Distance is the number of positions where the characters differ (Hamming distance).
  """
  def distance(individual1, individual2) do
    # Ensure genes are same length
    min_length = min(length(individual1.genes), length(individual2.genes))

    # Count differing positions
    Enum.zip(Enum.take(individual1.genes, min_length), Enum.take(individual2.genes, min_length))
    |> Enum.count(fn {a, b} -> a != b end)
  end
end
