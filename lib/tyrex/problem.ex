defmodule Tyrex.Problem do
  @moduledoc """
  A structure to define a problem for the genetic algorithm.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          genotype: module(),
          genotype_params: Keyword.t(),
          fitness_function: (any() -> number()),
          termination: (list(), integer() -> boolean()),
          metadata: map()
        }

  defstruct [
    :name,
    :genotype,
    :genotype_params,
    :fitness_function,
    :termination,
    metadata: %{}
  ]

  @doc """
  Creates a new problem definition.

  ## Examples

      iex> Tyrex.Problem.new("String Match",
      ...>   genotype: Tyrex.Genotypes.String,
      ...>   genotype_params: [length: 11],
      ...>   fitness_function: &string_match_fitness/1,
      ...>   termination: &max_fitness_termination/2
      ...> )
  """
  def new(name, opts \\ []) do
    %__MODULE__{
      name: name,
      genotype: Keyword.fetch!(opts, :genotype),
      genotype_params: Keyword.get(opts, :genotype_params, []),
      fitness_function: Keyword.fetch!(opts, :fitness_function),
      termination: Keyword.fetch!(opts, :termination),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Creates a termination function that stops when a fitness threshold is reached.
  """
  def termination_by_fitness(threshold) do
    fn population, _generation ->
      best = Enum.max_by(population, & &1.fitness)
      best.fitness >= threshold
    end
  end

  @doc """
  Creates a termination function that stops when fitness hasn't improved for n generations.
  """
  def termination_by_stagnation(generations) do
    fn _population, generation, stats ->
      if generation < generations do
        false
      else
        recent_best = Enum.slice(stats.best_fitness, -generations..-1)
        Enum.all?(recent_best, fn fitness -> fitness == hd(recent_best) end)
      end
    end
  end
end
