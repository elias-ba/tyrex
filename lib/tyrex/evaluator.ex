defmodule Tyrex.Evaluator do
  @moduledoc """
  Functions for evaluating the fitness of individuals.
  """

  @doc """
  Evaluates the fitness of each individual in the population.

  ## Options

  * `:max_concurrency` - Maximum number of concurrent evaluations (default: System.schedulers_online())
  * `:timeout` - Timeout for each evaluation in milliseconds (default: 5000)
  * `:distributed` - Whether to distribute evaluations across nodes (default: false)
  * `:chunk_size` - Size of chunks for distributed evaluation (default: 10)

  ## Examples

      iex> Tyrex.Evaluator.evaluate(population, fitness_function)
      iex> Tyrex.Evaluator.evaluate(population, fitness_function, max_concurrency: 4)
  """
  def evaluate(population, fitness_function, opts \\ []) do
    max_concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online())
    timeout = Keyword.get(opts, :timeout, 5000)
    distributed = Keyword.get(opts, :distributed, false)

    if distributed do
      evaluate_distributed(population, fitness_function, opts)
    else
      evaluate_parallel(population, fitness_function, max_concurrency, timeout)
    end
  end

  @doc """
  Evaluates the fitness of individuals in parallel.
  """
  def evaluate_parallel(population, fitness_function, max_concurrency, timeout) do
    population
    |> Task.async_stream(
      fn individual ->
        %{individual | fitness: fitness_function.(individual)}
      end,
      max_concurrency: max_concurrency,
      timeout: timeout
    )
    |> Enum.map(fn
      {:ok, individual} -> individual
      {:exit, reason} -> raise "Evaluation failed: #{inspect(reason)}"
    end)
  end

  @doc """
  Evaluates the fitness of individuals distributed across nodes.
  """
  def evaluate_distributed(population, fitness_function, opts) do
    chunk_size = Keyword.get(opts, :chunk_size, 10)
    timeout = Keyword.get(opts, :timeout, 5000)

    nodes = [node() | Node.list()]

    if length(nodes) <= 1 do
      evaluate_parallel(population, fitness_function, System.schedulers_online(), timeout)
    else
      population
      |> Enum.chunk_every(chunk_size)
      |> Enum.zip(Stream.cycle(nodes))
      |> Enum.flat_map(fn {chunk, node} ->
        Task.Supervisor.async({Tyrex.TaskSupervisor, node}, fn ->
          Enum.map(chunk, fn individual ->
            %{individual | fitness: fitness_function.(individual)}
          end)
        end)
        |> Task.await(timeout)
      end)
    end
  end

  @doc """
  Creates a memoized fitness function that caches results.
  """
  def memoize(fitness_function) do
    table = :ets.new(:fitness_cache, [:set, :public])

    fn individual ->
      key = :erlang.phash2(individual)

      case :ets.lookup(table, key) do
        [{^key, fitness}] ->
          fitness

        [] ->
          fitness = fitness_function.(individual)
          :ets.insert(table, {key, fitness})
          fitness
      end
    end
  end
end
