defmodule Tyrex.Mutation do
  @moduledoc """
  Mutation operations for genetic algorithms.
  """

  @doc """
  Performs mutation on the population.

  ## Examples

      iex> Tyrex.Mutation.mutate(population, &Tyrex.Genotypes.String.mutate/1, 0.05)
  """
  def mutate(population, mutation_fn, rate) do
    Enum.map(population, fn individual ->
      if :rand.uniform() < rate do
        mutation_fn.(individual)
      else
        individual
      end
    end)
  end

  @doc """
  Default implementation for point mutation.

  This mutation randomly changes a single gene.

  ## Options

  * `:gene_pool` - Pool of possible gene values (required)
  """
  def point(individual, options) do
    gene_pool = Keyword.fetch!(options, :gene_pool)

    if length(individual.genes) == 0 do
      individual
    else
      # Choose a random position to mutate
      position = :rand.uniform(length(individual.genes)) - 1

      # Choose a random gene from the gene pool
      new_gene = Enum.random(gene_pool)

      # Create a new individual with the mutated gene
      genes = List.update_at(individual.genes, position, fn _ -> new_gene end)
      %{individual | genes: genes, fitness: 0}
    end
  end

  @doc """
  Default implementation for swap mutation.

  This mutation swaps two genes in the individual.
  """
  def swap(individual, _options \\ []) do
    if length(individual.genes) < 2 do
      individual
    else
      # Choose two random positions to swap
      pos1 = :rand.uniform(length(individual.genes)) - 1
      pos2 = :rand.uniform(length(individual.genes)) - 1

      # Ensure positions are different
      pos2 =
        if pos1 == pos2 do
          rem(pos1 + 1, length(individual.genes))
        else
          pos2
        end

      # Get the genes at the positions
      gene1 = Enum.at(individual.genes, pos1)
      gene2 = Enum.at(individual.genes, pos2)

      # Create a new individual with the swapped genes
      genes =
        individual.genes
        |> List.update_at(pos1, fn _ -> gene2 end)
        |> List.update_at(pos2, fn _ -> gene1 end)

      %{individual | genes: genes, fitness: 0}
    end
  end

  @doc """
  Default implementation for scramble mutation.

  This mutation scrambles a random subset of genes.
  """
  def scramble(individual, _options \\ []) do
    if length(individual.genes) < 2 do
      individual
    else
      # Choose a random subset to scramble
      pos1 = :rand.uniform(length(individual.genes)) - 1
      pos2 = :rand.uniform(length(individual.genes)) - 1

      # Ensure positions are different
      pos2 =
        if pos1 == pos2 do
          rem(pos1 + 1, length(individual.genes))
        else
          pos2
        end

      # Sort positions
      [start, finish] = Enum.sort([pos1, pos2])

      # Extract the subset
      {prefix, rest} = Enum.split(individual.genes, start)
      {subset, suffix} = Enum.split(rest, finish - start + 1)

      # Scramble the subset
      scrambled = Enum.shuffle(subset)

      # Create a new individual with the scrambled subset
      genes = prefix ++ scrambled ++ suffix
      %{individual | genes: genes, fitness: 0}
    end
  end

  @doc """
  Default implementation for inversion mutation.

  This mutation inverts a random subset of genes.
  """
  def inversion(individual, _options \\ []) do
    if length(individual.genes) < 2 do
      individual
    else
      # Choose a random subset to invert
      pos1 = :rand.uniform(length(individual.genes)) - 1
      pos2 = :rand.uniform(length(individual.genes)) - 1

      # Ensure positions are different
      pos2 =
        if pos1 == pos2 do
          rem(pos1 + 1, length(individual.genes))
        else
          pos2
        end

      # Sort positions
      [start, finish] = Enum.sort([pos1, pos2])

      # Extract the subset
      {prefix, rest} = Enum.split(individual.genes, start)
      {subset, suffix} = Enum.split(rest, finish - start + 1)

      # Invert the subset
      inverted = Enum.reverse(subset)

      # Create a new individual with the inverted subset
      genes = prefix ++ inverted ++ suffix
      %{individual | genes: genes, fitness: 0}
    end
  end

  @doc """
  Default implementation for multi-point mutation.

  This mutation changes multiple genes with a certain probability.

  ## Options

  * `:gene_pool` - Pool of possible gene values (required)
  * `:point_rate` - Probability of mutating each gene (default: 0.1)
  """
  def multi_point(individual, options) do
    gene_pool = Keyword.fetch!(options, :gene_pool)
    point_rate = Keyword.get(options, :point_rate, 0.1)

    # Mutate each gene with probability point_rate
    genes =
      Enum.map(individual.genes, fn gene ->
        if :rand.uniform() < point_rate do
          Enum.random(gene_pool)
        else
          gene
        end
      end)

    %{individual | genes: genes, fitness: 0}
  end
end
