defmodule Tyrex.NEAT do
  @moduledoc """
  NeuroEvolution of Augmenting Topologies (NEAT) algorithm.

  NEAT evolves both the topology and connection weights of neural networks.
  It uses a direct encoding and speciation to protect innovation.
  """

  alias Tyrex.NEAT.{Genome, Network, Species, InnovationCounter}

  @doc """
  Runs the NEAT algorithm for the given problem.

  ## Options

  * `:population_size` - Size of the population (default: 150)
  * `:max_generations` - Maximum number of generations to run (default: 500)
  * `:compatibility_threshold` - Threshold for species compatibility (default: 3.0)
  * `:mutation_rates` - Map of mutation rates (default: standard rates)
  * `:inputs` - Number of input nodes (default: 3)
  * `:outputs` - Number of output nodes (default: 1)
  * `:elitism` - Number of elite individuals to keep per species (default: 1)
  * `:crossover_rate` - Probability of crossover (default: 0.7)
  * `:parallel` - Options for parallel processing (default: [])
  """
  def run(problem, opts \\ []) do
    # Get options
    population_size = Keyword.get(opts, :population_size, 150)
    max_generations = Keyword.get(opts, :max_generations, 500)
    compatibility_threshold = Keyword.get(opts, :compatibility_threshold, 3.0)

    mutation_rates =
      Keyword.get(opts, :mutation_rates, %{
        add_node_rate: 0.03,
        add_connection_rate: 0.05,
        weight_mutation_rate: 0.8,
        toggle_connection_rate: 0.01
      })

    inputs = Keyword.get(opts, :inputs, 3)
    outputs = Keyword.get(opts, :outputs, 1)
    elitism = Keyword.get(opts, :elitism, 1)
    crossover_rate = Keyword.get(opts, :crossover_rate, 0.7)
    parallel_opts = Keyword.get(opts, :parallel, [])

    # Reset innovation counter
    InnovationCounter.reset()

    # Create a statistics structure to track progress
    stats = %Tyrex.Statistics{}

    # Initialize population
    population = initialize_population(population_size, inputs, outputs)

    # Run evolution loop
    evolve(
      population,
      problem,
      %{
        compatibility_threshold: compatibility_threshold,
        mutation_rates: mutation_rates,
        inputs: inputs,
        outputs: outputs,
        elitism: elitism,
        crossover_rate: crossover_rate,
        parallel_opts: parallel_opts
      },
      %{},
      stats,
      0,
      max_generations
    )
  end

  @doc """
  Runs the NEAT algorithm asynchronously as a supervised process.

  Returns a run_id that can be used to check status and retrieve results.
  """
  def run_async(problem, opts \\ []) do
    # Generate a unique ID for this run
    run_id = System.unique_integer([:positive]) |> to_string

    # Start a new evolution process
    {:ok, _pid} =
      DynamicSupervisor.start_child(
        Tyrex.EvolutionSupervisor,
        {Tyrex.NEAT.EvolutionProcess, [run_id: run_id, problem: problem, opts: opts]}
      )

    run_id
  end

  @doc """
  Gets the current status of an asynchronous evolution run.
  """
  def status(run_id) do
    # Look up the process by run_id
    case Registry.lookup(Tyrex.Registry, run_id) do
      [{pid, _}] -> GenServer.call(pid, :status)
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Stops an asynchronous evolution run.
  """
  def stop(run_id) do
    # Look up the process by run_id
    case Registry.lookup(Tyrex.Registry, run_id) do
      [{pid, _}] -> DynamicSupervisor.terminate_child(Tyrex.EvolutionSupervisor, pid)
      [] -> {:error, :not_found}
    end
  end

  # Private function to initialize the population
  defp initialize_population(size, inputs, outputs) do
    for _ <- 1..size do
      Genome.create(inputs: inputs, outputs: outputs)
    end
  end

  # Private function to run the evolution loop
  defp evolve(
         population,
         problem,
         params,
         species_representatives,
         stats,
         generation,
         max_generations
       ) do
    # Evaluate fitness
    population = evaluate_population(population, problem.fitness_function, params.parallel_opts)

    # Sort by fitness
    sorted_population = Enum.sort_by(population, & &1.fitness, :desc)
    best = hd(sorted_population)

    # Update statistics
    stats = Tyrex.Statistics.update(stats, sorted_population, generation)

    # Check termination criteria
    if problem.termination.(sorted_population, generation) || generation >= max_generations do
      {best, stats}
    else
      # Speciate the population
      {species_members, new_representatives} =
        Species.speciate(sorted_population,
          compatibility_threshold: params.compatibility_threshold,
          species_representatives: species_representatives
        )

      # Adjust fitness
      _adjusted_population = Species.adjust_fitness(species_members)

      # Allocate offspring
      offspring_allocation = Species.allocate_offspring(species_members, length(population))

      # Create next generation
      next_generation =
        Species.create_next_generation(species_members, offspring_allocation,
          elitism: params.elitism,
          crossover_rate: params.crossover_rate,
          mutation_rates: params.mutation_rates
        )

      # Recur to next generation
      evolve(
        next_generation,
        problem,
        params,
        new_representatives,
        stats,
        generation + 1,
        max_generations
      )
    end
  end

  # Private function to evaluate the fitness of the population
  defp evaluate_population(population, fitness_function, parallel_opts) do
    # Create a wrapper fitness function that builds and activates networks
    wrapped_fitness_fn = fn genome ->
      network = Network.create(genome)
      fitness = fitness_function.(genome, network)
      %{genome | fitness: fitness}
    end

    # Evaluate using the evaluator
    Tyrex.Evaluator.evaluate(population, wrapped_fitness_fn, parallel_opts)
  end
end
