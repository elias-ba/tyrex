defmodule Tyrex.Examples.Abracadabra do
  @moduledoc """
  Example of solving the abracadabra problem with genetic algorithms.

  The abracadabra problem is to evolve a program that produces the string "abracadabra".
  """

  @doc """
  Runs the example using the standard genetic algorithm approach.
  """
  def run_standard do
    problem = %Tyrex.Problem{
      name: "Abracadabra",
      genotype: Tyrex.Genotypes.String,
      genotype_params: [length: 11],  # "abracadabra" has 11 characters
      fitness_function: &fitness_function/1,
      termination: &termination_function/2
    }

    {best, stats} = Tyrex.run(problem,
      population_size: 100,
      max_generations: 100,
      selection_strategy: {Tyrex.Selection.Tournament, tournament_size: 3},
      crossover_rate: 0.7,
      mutation_rate: 0.05
    )

    IO.puts("=== Abracadabra Problem (Standard GA) ===")
    IO.puts("Best solution: #{Tyrex.Genotypes.String.to_string(best)}")
    IO.puts("Fitness: #{best.fitness}")
    IO.puts("Generations: #{stats.generations}")
    IO.puts("Duration: #{stats.duration} seconds")

    {best, stats}
  end

  @doc """
  Runs the example using the NEAT approach.
  """
  def run_neat do
    problem = %Tyrex.Problem{
      name: "Abracadabra NEAT",
      fitness_function: &neat_fitness_function/2,
      termination: &termination_function/2
    }

    target = "abracadabra"
    input_size = String.length(target)

    {best, stats} = Tyrex.NEAT.run(problem,
      population_size: 150,
      max_generations: 300,
      compatibility_threshold: 3.0,
      inputs: input_size,
      outputs: 26,
      bias: false,
      mutation_rates: %{
        add_node_rate: 0.03,
        add_connection_rate: 0.05,
        weight_mutation_rate: 0.8,
        toggle_connection_rate: 0.01
      }
    )

    network = Tyrex.NEAT.Network.create(best)
    solution = decode_neat_output(network)

    IO.puts("=== Abracadabra Problem (NEAT) ===")
    IO.puts("Best solution: #{solution}")
    IO.puts("Fitness: #{best.fitness}")
    IO.puts("Generations: #{stats.generations}")
    IO.puts("Duration: #{stats.duration} seconds")
    IO.puts("Network complexity: #{length(best.genes)} connections, #{MapSet.size(best.nodes)} nodes")

    {best, stats, solution}
  end

  defp fitness_function(individual) do
    target = "abracadabra"
    candidate = Tyrex.Genotypes.String.to_string(individual)

    target_chars = String.to_charlist(target)
    candidate_chars = String.to_charlist(candidate)

    Enum.zip(target_chars, candidate_chars)
    |> Enum.count(fn {a, b} -> a == b end)
  end

  defp neat_fitness_function(_genome, network) do
    target = "abracadabra"
    target_chars = String.to_charlist(target)
    input_size = String.length(target)

    # Use Enum.reduce to count correct characters
    Enum.reduce(0..(input_size - 1), 0, fn pos, acc ->
      inputs = List.duplicate(0.0, input_size)
              |> List.update_at(pos, fn _ -> 1.0 end)

      outputs = Tyrex.NEAT.Network.activate(network, inputs)

      {_, max_idx} = outputs
                     |> Enum.with_index()
                     |> Enum.max_by(fn {val, _} -> val end)

      output_char = max_idx + ?a
      target_char = Enum.at(target_chars, pos)

      if output_char == target_char do
        acc + 1
      else
        acc
      end
    end)
  end

  defp termination_function(population, _generation) do
    best = Enum.max_by(population, & &1.fitness)
    best.fitness >= 11  # "abracadabra" has 11 characters
  end

  defp decode_neat_output(network) do
    target = "abracadabra"
    input_size = String.length(target)

    Enum.map(0..(input_size - 1), fn pos ->
      inputs = List.duplicate(0.0, input_size)
              |> List.update_at(pos, fn _ -> 1.0 end)

      outputs = Tyrex.NEAT.Network.activate(network, inputs)

      {_, max_idx} = outputs
                     |> Enum.with_index()
                     |> Enum.max_by(fn {val, _} -> val end)

      max_idx + ?a
    end)
    |> List.to_string()
  end
end
