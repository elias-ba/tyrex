defmodule Tyrex.Selection do
  @moduledoc """
  Selection strategies for genetic algorithms.
  """

  @doc """
  Selects individuals from the population based on the given selection strategy.

  ## Examples

      iex> Tyrex.Selection.select(population, {Tyrex.Selection.Tournament, tournament_size: 3})
  """
  def select(population, {strategy, opts}) do
    strategy.select(population, opts)
  end

  def select(population, strategy) when is_atom(strategy) do
    strategy.select(population, [])
  end

  @doc """
  Tournament selection module.
  """
  defmodule Tournament do
    @moduledoc """
    Tournament selection strategy.

    Tournament selection works by selecting a random subset of individuals from the
    population and choosing the best from that subset.
    """

    @doc """
    Performs tournament selection.

    ## Options

    * `:tournament_size` - Size of each tournament (default: 3)
    * `:selection_size` - Number of individuals to select (default: length(population))
    """
    def select(population, opts \\ []) do
      tournament_size = Keyword.get(opts, :tournament_size, 3)
      selection_size = Keyword.get(opts, :selection_size, length(population))

      for _ <- 1..selection_size do
        # Select tournament_size individuals at random
        tournament = Enum.take_random(population, min(tournament_size, length(population)))

        # Return the best individual from the tournament
        Enum.max_by(tournament, & &1.fitness)
      end
    end
  end

  @doc """
  Roulette wheel selection module.
  """
  defmodule Roulette do
    @moduledoc """
    Roulette wheel selection strategy.

    Roulette wheel selection works by selecting individuals with probability
    proportional to their fitness.
    """

    @doc """
    Performs roulette wheel selection.

    ## Options

    * `:selection_size` - Number of individuals to select (default: length(population))
    """
    def select(population, opts \\ []) do
      selection_size = Keyword.get(opts, :selection_size, length(population))

      # Calculate total fitness
      total_fitness = Enum.sum(Enum.map(population, & &1.fitness))

      # Handle case of zero total fitness
      if total_fitness <= 0 do
        Enum.take_random(population, selection_size)
      else
        # Calculate selection probabilities
        wheel =
          Enum.scan(population, 0, fn individual, acc ->
            acc + individual.fitness / total_fitness
          end)

        # Select individuals
        for _ <- 1..selection_size do
          # Spin the wheel
          spin = :rand.uniform()

          # Find the selected individual
          {individual, _} =
            Enum.zip(population, wheel)
            |> Enum.find({hd(population), 0}, fn {_, prob} -> prob >= spin end)

          individual
        end
      end
    end
  end

  @doc """
  Rank selection module.
  """
  defmodule Rank do
    @moduledoc """
    Rank selection strategy.

    Rank selection works by selecting individuals with probability
    proportional to their rank in the population sorted by fitness.
    """

    @doc """
    Performs rank selection.

    ## Options

    * `:selection_size` - Number of individuals to select (default: length(population))
    * `:selection_pressure` - Selection pressure parameter (default: 1.5)
    """
    def select(population, opts \\ []) do
      selection_size = Keyword.get(opts, :selection_size, length(population))
      selection_pressure = Keyword.get(opts, :selection_pressure, 1.5)

      # Sort population by fitness
      sorted_population = Enum.sort_by(population, & &1.fitness, :desc)

      # Assign ranks
      ranks = Enum.with_index(sorted_population, 1)

      # Calculate rank probabilities
      n = length(population)
      total_rank = n * (n + 1) / 2

      wheel =
        Enum.scan(ranks, 0, fn {{individual, _}, rank}, acc ->
          prob = rank / total_rank * selection_pressure
          acc + prob
        end)

      # Select individuals
      for _ <- 1..selection_size do
        # Spin the wheel
        spin = :rand.uniform()

        # Find the selected individual
        {{individual, _}, _} =
          Enum.zip(ranks, wheel)
          |> Enum.find({{hd(sorted_population), 0}, 0}, fn {_, prob} -> prob >= spin end)

        individual
      end
    end
  end

  @doc """
  Elitism selection module.
  """
  defmodule Elitism do
    @moduledoc """
    Elitism selection strategy.

    Elitism selection works by keeping the best individuals from the population
    and selecting the rest using another selection strategy.
    """

    @doc """
    Performs elitism selection.

    ## Options

    * `:elite_count` - Number of elite individuals to keep (default: 1)
    * `:base_strategy` - Selection strategy for the rest (default: {Tournament, []})
    """
    def select(population, opts \\ []) do
      elite_count = Keyword.get(opts, :elite_count, 1)
      base_strategy = Keyword.get(opts, :base_strategy, {Tournament, []})

      # Sort population by fitness
      sorted_population = Enum.sort_by(population, & &1.fitness, :desc)

      # Keep elites
      elites = Enum.take(sorted_population, elite_count)

      # Select the rest
      rest_size = length(population) - elite_count

      rest =
        Tyrex.Selection.select(sorted_population, base_strategy)
        |> Enum.take(rest_size)

      # Combine elites and selected individuals
      elites ++ rest
    end
  end
end
