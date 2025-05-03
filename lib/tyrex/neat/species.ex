defmodule Tyrex.NEAT.Species do
  @moduledoc """
  Species management for NEAT.

  This module handles the speciation of genomes in NEAT, which is used to
  protect innovation and maintain diversity.
  """

  alias Tyrex.NEAT.Genome

  @doc """
  Speciate a population of genomes.

  Divides the population into species based on genetic similarity.

  ## Options

  * `:compatibility_threshold` - Threshold for species compatibility (default: 3.0)
  * `:species_representatives` - Map of species representatives (default: nil)
  """
  def speciate(population, opts \\ []) do
    compatibility_threshold = Keyword.get(opts, :compatibility_threshold, 3.0)
    representatives = Keyword.get(opts, :species_representatives, %{})

    if map_size(representatives) == 0 && length(population) > 0 do
      [first | rest] = population
      first = %{first | species_id: 1}
      representatives = %{1 => first}

      {species_members, updated_representatives} =
        process_population(rest, representatives, compatibility_threshold)

      species_members =
        Map.update(species_members, 1, [first], fn members -> [first | members] end)

      {species_members, updated_representatives}
    else
      process_population(population, representatives, compatibility_threshold)
    end
  end

  @doc """
  Calculates adjusted fitness for each genome based on its species.

  This implements explicit fitness sharing, where fitness is shared
  among members of the same species.
  """
  def adjust_fitness(species_members) do
    species_members
    |> Enum.flat_map(fn {_species_id, members} ->
      n = length(members)

      Enum.map(members, fn genome ->
        %{genome | adjusted_fitness: genome.fitness / n}
      end)
    end)
  end

  @doc """
  Allocates offspring to species based on their adjusted fitness.

  Returns a map of species ID to number of offspring.
  """
  def allocate_offspring(species_members, population_size) do
    species_fitness =
      Enum.map(species_members, fn {species_id, members} ->
        total_adjusted_fitness = Enum.sum(Enum.map(members, & &1.adjusted_fitness))
        {species_id, total_adjusted_fitness}
      end)
      |> Enum.filter(fn {_, fitness} -> fitness > 0 end)

    total_fitness = Enum.sum(Enum.map(species_fitness, fn {_, fitness} -> fitness end))

    if total_fitness <= 0 do
      species_count = map_size(species_members)
      equal_share = div(population_size, max(1, species_count))

      Map.new(Map.keys(species_members), fn species_id -> {species_id, equal_share} end)
    else
      offspring =
        Enum.map(species_fitness, fn {species_id, fitness} ->
          expected = fitness / total_fitness * population_size

          {species_id, max(1, trunc(expected))}
        end)
        |> Map.new()

      adjust_offspring_count(offspring, population_size)
    end
  end

  @doc """
  Creates the next generation of genomes based on offspring allocation.

  ## Options

  * `:elitism` - Number of elites to keep per species (default: 1)
  * `:crossover_rate` - Probability of crossover (default: 0.7)
  * `:mutation_rates` - Map of mutation rates (default: standard rates)
  """
  def create_next_generation(species_members, offspring_allocation, opts \\ []) do
    elitism = Keyword.get(opts, :elitism, 1)
    crossover_rate = Keyword.get(opts, :crossover_rate, 0.7)

    mutation_rates =
      Keyword.get(opts, :mutation_rates, %{
        add_node_rate: 0.03,
        add_connection_rate: 0.05,
        weight_mutation_rate: 0.8,
        toggle_connection_rate: 0.01
      })

    Enum.flat_map(species_members, fn {species_id, members} ->
      sorted_members = Enum.sort_by(members, & &1.fitness, :desc)

      offspring_count = Map.get(offspring_allocation, species_id, 0)

      if offspring_count > 0 do
        elite_count = min(elitism, offspring_count)
        elites = Enum.take(sorted_members, elite_count)

        offspring_needed = offspring_count - elite_count

        offspring =
          if offspring_needed > 0 && length(sorted_members) > 0 do
            create_offspring(
              sorted_members,
              offspring_needed,
              species_id,
              crossover_rate,
              mutation_rates
            )
          else
            []
          end

        elites ++ offspring
      else
        []
      end
    end)
  end

  @doc """
  Gets representative genomes for each species.
  """
  def get_representatives(species_members) do
    Enum.map(species_members, fn {species_id, members} ->
      {species_id, Enum.random(members)}
    end)
    |> Map.new()
  end

  defp process_population(population, representatives, compatibility_threshold) do
    species_members = Map.new(Map.keys(representatives), fn id -> {id, []} end)

    Enum.reduce(population, {species_members, representatives}, fn genome, {members, reps} ->
      {species_id, updated_reps} = find_species(genome, reps, compatibility_threshold)

      updated_genome = %{genome | species_id: species_id}

      updated_members =
        Map.update(members, species_id, [updated_genome], fn ms -> [updated_genome | ms] end)

      {updated_members, updated_reps}
    end)
  end

  defp find_species(genome, representatives, compatibility_threshold) do
    species_match =
      Enum.find(representatives, fn {_, rep} ->
        Genome.distance(genome, rep) < compatibility_threshold
      end)

    case species_match do
      {id, _} ->
        {id, representatives}

      nil ->
        new_id = map_size(representatives) + 1
        {new_id, Map.put(representatives, new_id, genome)}
    end
  end

  defp adjust_offspring_count(offspring, target_size) do
    total = Enum.sum(Map.values(offspring))

    cond do
      total < target_size ->
        diff = target_size - total

        sorted_species = Enum.sort_by(offspring, fn {_, count} -> count end, :desc)

        Enum.reduce(1..diff, offspring, fn _, acc ->
          [{id, _} | _] = sorted_species
          Map.update(acc, id, 1, &(&1 + 1))
        end)

      total > target_size ->
        diff = total - target_size

        sorted_species = Enum.sort_by(offspring, fn {_, count} -> count end)

        Enum.reduce(1..diff, offspring, fn _, acc ->
          [{id, _count} | _] = Enum.filter(sorted_species, fn {_, c} -> c > 1 end)
          Map.update(acc, id, 0, &(&1 - 1))
        end)

      true ->
        offspring
    end
  end

  defp create_offspring(members, count, species_id, crossover_rate, mutation_rates) do
    for _ <- 1..count do
      parent1 = tournament_selection(members)
      parent2 = tournament_selection(members)

      child =
        if :rand.uniform() < crossover_rate && length(members) > 1 do
          offspring = Genome.crossover(parent1, parent2)
          %{offspring | species_id: species_id}
        else
          %{parent1 | species_id: species_id}
        end

      Genome.mutate(child, Map.to_list(mutation_rates))
    end
  end

  defp tournament_selection(members, tournament_size \\ 3) do
    tournament = Enum.take_random(members, min(tournament_size, length(members)))

    Enum.max_by(tournament, & &1.fitness)
  end
end
