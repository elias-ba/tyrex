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

    # If no representatives, create new species with first genome
    if map_size(representatives) == 0 && length(population) > 0 do
      [first | rest] = population
      first = %{first | species_id: 1}
      representatives = %{1 => first}

      # Process the rest of the population
      {species_members, updated_representatives} =
        process_population(rest, representatives, compatibility_threshold)

      # Add the first genome to its species
      species_members =
        Map.update(species_members, 1, [first], fn members -> [first | members] end)

      {species_members, updated_representatives}
    else
      # Process the population
      process_population(population, representatives, compatibility_threshold)
    end
  end

  @doc """
  Calculates adjusted fitness for each genome based on its species.

  This implements explicit fitness sharing, where fitness is shared
  among members of the same species.
  """
  def adjust_fitness(species_members) do
    # For each species, adjust the fitness of its members
    species_members
    |> Enum.flat_map(fn {_species_id, members} ->
      # Number of members in this species
      n = length(members)

      # Adjust fitness for each member
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
    # Calculate total adjusted fitness for each species
    species_fitness =
      Enum.map(species_members, fn {species_id, members} ->
        total_adjusted_fitness = Enum.sum(Enum.map(members, & &1.adjusted_fitness))
        {species_id, total_adjusted_fitness}
      end)
      |> Enum.filter(fn {_, fitness} -> fitness > 0 end)

    # Calculate total adjusted fitness across all species
    total_fitness = Enum.sum(Enum.map(species_fitness, fn {_, fitness} -> fitness end))

    if total_fitness <= 0 do
      # If total fitness is zero or negative, allocate equally
      species_count = map_size(species_members)
      equal_share = div(population_size, max(1, species_count))

      Map.new(Map.keys(species_members), fn species_id -> {species_id, equal_share} end)
    else
      # Allocate offspring based on adjusted fitness proportion
      offspring =
        Enum.map(species_fitness, fn {species_id, fitness} ->
          # Calculate expected offspring
          expected = fitness / total_fitness * population_size

          # Ensure at least one offspring if the species has any fitness
          {species_id, max(1, trunc(expected))}
        end)
        |> Map.new()

      # Adjust for rounding errors to ensure we get exactly population_size offspring
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

    # For each species, create the next generation
    Enum.flat_map(species_members, fn {species_id, members} ->
      # Sort members by fitness
      sorted_members = Enum.sort_by(members, & &1.fitness, :desc)

      # Get the number of offspring for this species
      offspring_count = Map.get(offspring_allocation, species_id, 0)

      if offspring_count > 0 do
        # Keep elites (but no more than offspring_count)
        elite_count = min(elitism, offspring_count)
        elites = Enum.take(sorted_members, elite_count)

        # Create offspring for the rest
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

        # Combine elites and offspring
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
    # For each species, select a random member as representative
    Enum.map(species_members, fn {species_id, members} ->
      {species_id, Enum.random(members)}
    end)
    |> Map.new()
  end

  # Helper function to process the population for speciation
  defp process_population(population, representatives, compatibility_threshold) do
    # Initialize species members
    species_members = Map.new(Map.keys(representatives), fn id -> {id, []} end)

    # Process each genome
    Enum.reduce(population, {species_members, representatives}, fn genome, {members, reps} ->
      # Find the species this genome belongs to
      {species_id, updated_reps} = find_species(genome, reps, compatibility_threshold)

      # Add the genome to its species
      updated_genome = %{genome | species_id: species_id}

      updated_members =
        Map.update(members, species_id, [updated_genome], fn ms -> [updated_genome | ms] end)

      {updated_members, updated_reps}
    end)
  end

  # Helper function to find the species a genome belongs to
  defp find_species(genome, representatives, compatibility_threshold) do
    # Find the first species with distance below threshold
    species_match =
      Enum.find(representatives, fn {_, rep} ->
        Genome.distance(genome, rep) < compatibility_threshold
      end)

    case species_match do
      {id, _} ->
        # Genome belongs to an existing species
        {id, representatives}

      nil ->
        # Create a new species for this genome
        new_id = map_size(representatives) + 1
        {new_id, Map.put(representatives, new_id, genome)}
    end
  end

  # Helper function to adjust offspring count to match population size
  defp adjust_offspring_count(offspring, target_size) do
    total = Enum.sum(Map.values(offspring))

    cond do
      total < target_size ->
        # Need to add offspring
        diff = target_size - total

        # Add to the species with highest fitness first
        sorted_species = Enum.sort_by(offspring, fn {_, count} -> count end, :desc)

        Enum.reduce(1..diff, offspring, fn _, acc ->
          [{id, _} | _] = sorted_species
          Map.update(acc, id, 1, &(&1 + 1))
        end)

      total > target_size ->
        # Need to remove offspring
        diff = total - target_size

        # Remove from the species with lowest fitness first
        sorted_species = Enum.sort_by(offspring, fn {_, count} -> count end)

        Enum.reduce(1..diff, offspring, fn _, acc ->
          [{id, _count} | _] = Enum.filter(sorted_species, fn {_, c} -> c > 1 end)
          Map.update(acc, id, 0, &(&1 - 1))
        end)

      true ->
        # Already matching
        offspring
    end
  end

  # Helper function to create offspring for a species
  defp create_offspring(members, count, species_id, crossover_rate, mutation_rates) do
    for _ <- 1..count do
      # Select parents
      parent1 = tournament_selection(members)
      parent2 = tournament_selection(members)

      # Create offspring
      child =
        if :rand.uniform() < crossover_rate && length(members) > 1 do
          # Crossover
          offspring = Genome.crossover(parent1, parent2)
          %{offspring | species_id: species_id}
        else
          # No crossover, just clone parent1
          %{parent1 | species_id: species_id}
        end

      # Mutate
      Genome.mutate(child, Map.to_list(mutation_rates))
    end
  end

  # Helper function for tournament selection
  defp tournament_selection(members, tournament_size \\ 3) do
    # Select tournament_size random members
    tournament = Enum.take_random(members, min(tournament_size, length(members)))

    # Return the best
    Enum.max_by(tournament, & &1.fitness)
  end
end
