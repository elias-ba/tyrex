defmodule Tyrex do
  @moduledoc """
  Tyrex is a comprehensive genetic programming and neuroevolution library for Elixir.

  It provides implementations of standard genetic algorithms as well as the NEAT
  (NeuroEvolution of Augmenting Topologies) algorithm.

  ## Basic Usage

  ```elixir
  # Define a problem
  problem = %Tyrex.Problem{
    name: "String Match",
    target: "abracadabra",
    genotype: Tyrex.Genotypes.String,
    fitness_function: &string_match_fitness/1,
    termination: &max_fitness_termination/2
  }

  # Run the algorithm
  result = Tyrex.run(problem)
  ```
  """

  alias Tyrex.{Evaluator, Selection, Crossover, Mutation}

  @doc """
  Runs a genetic algorithm for the given problem with the specified options.

  ## Options

  * `:population_size` - Size of the population (default: 100)
  * `:max_generations` - Maximum number of generations to run (default: 1000)
  * `:selection_strategy` - Strategy for selection (default: Tyrex.Selection.Tournament)
  * `:crossover_rate` - Probability of crossover (default: 0.7)
  * `:mutation_rate` - Probability of mutation (default: 0.05)
  * `:elitism` - Number of elite individuals to keep (default: 1)
  * `:parallel` - Options for parallel processing (default: [])
  """
  def run(problem, opts \\ []) do
    population_size = Keyword.get(opts, :population_size, 100)
    max_generations = Keyword.get(opts, :max_generations, 1000)

    selection_strategy =
      Keyword.get(opts, :selection_strategy, {Selection.Tournament, tournament_size: 3})

    crossover_rate = Keyword.get(opts, :crossover_rate, 0.7)
    mutation_rate = Keyword.get(opts, :mutation_rate, 0.05)
    elitism = Keyword.get(opts, :elitism, 1)
    parallel_opts = Keyword.get(opts, :parallel, [])

    stats = %Tyrex.Statistics{}

    population = problem.genotype.initialize(population_size, problem.genotype_params || [])

    evolve(
      population,
      problem,
      selection_strategy,
      crossover_rate,
      mutation_rate,
      elitism,
      parallel_opts,
      stats,
      0,
      max_generations,
      population_size
    )
  end

  @doc """
  Runs a genetic algorithm asynchronously as a supervised process.

  Returns a run_id that can be used to check status and retrieve results.
  """
  def run_async(problem, opts \\ []) do
    run_id = System.unique_integer([:positive]) |> to_string

    {:ok, _pid} =
      DynamicSupervisor.start_child(
        Tyrex.EvolutionSupervisor,
        {Tyrex.EvolutionProcess, [run_id: run_id, problem: problem, opts: opts]}
      )

    run_id
  end

  @doc """
  Gets the current status of an asynchronous evolution run.
  """
  def status(run_id) do
    case Registry.lookup(Tyrex.Registry, run_id) do
      [{pid, _}] -> GenServer.call(pid, :status)
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Stops an asynchronous evolution run.
  """
  def stop(run_id) do
    case Registry.lookup(Tyrex.Registry, run_id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(Tyrex.EvolutionSupervisor, pid)
      [] -> {:error, :not_found}
    end
  end

  defp evolve(
         population,
         problem,
         selection_strategy,
         crossover_rate,
         mutation_rate,
         elitism,
         parallel_opts,
         stats,
         generation,
         max_generations,
         population_size
       ) do
    population = Evaluator.evaluate(population, problem.fitness_function, parallel_opts)

    sorted_population = Enum.sort_by(population, & &1.fitness, :desc)
    best = hd(sorted_population)

    stats = Tyrex.Statistics.update(stats, sorted_population, generation)

    if problem.termination.(sorted_population, generation) || generation >= max_generations do
      {best, stats}
    else
      elites = Enum.take(sorted_population, elitism)

      next_generation =
        sorted_population
        |> Selection.select(selection_strategy)
        |> Crossover.crossover(&problem.genotype.crossover(&1, &2, []), crossover_rate)
        |> Mutation.mutate(&problem.genotype.mutate(&1, []), mutation_rate)

      next_generation_with_elites =
        elites ++ Enum.take(next_generation, population_size - elitism)

      evolve(
        next_generation_with_elites,
        problem,
        selection_strategy,
        crossover_rate,
        mutation_rate,
        elitism,
        parallel_opts,
        stats,
        generation + 1,
        max_generations,
        population_size
      )
    end
  end
end
