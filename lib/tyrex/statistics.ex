defmodule Tyrex.Statistics do
  @moduledoc """
  Statistics for tracking evolution progress.
  """

  @type t :: %__MODULE__{
          start_time: DateTime.t() | nil,
          end_time: DateTime.t() | nil,
          generations: non_neg_integer(),
          best_individual: struct() | nil,
          best_fitness: [number()],
          avg_fitness: [number()],
          std_fitness: [number()],
          population_sizes: [non_neg_integer()],
          diversity: [number()],
          duration: float()
        }

  @derive Jason.Encoder

  defstruct [
    :start_time,
    :end_time,
    generations: 0,
    best_individual: nil,
    best_fitness: [],
    avg_fitness: [],
    std_fitness: [],
    population_sizes: [],
    diversity: [],
    duration: 0.0
  ]

  @doc """
  Creates a new statistics struct.
  """
  def new do
    %__MODULE__{
      start_time: DateTime.utc_now()
    }
  end

  @doc """
  Updates statistics with the current population and generation.
  """
  def update(stats, population, generation, opts \\ []) do
    sorted_population = Enum.sort_by(population, & &1.fitness, :desc)
    best = hd(sorted_population)
    avg_fitness = Enum.sum(Enum.map(population, & &1.fitness)) / length(population)

    diversity =
      case Keyword.get(opts, :distance_fn) do
        nil ->
          stats.diversity

        distance_fn ->
          current_diversity = Tyrex.Population.diversity(population, distance_fn)
          stats.diversity ++ [current_diversity]
      end

    fitness_values = [best.fitness | Enum.map(population, & &1.fitness)]
    variance = calculate_variance(fitness_values)

    %{
      stats
      | generations: generation,
        best_individual: best,
        best_fitness: stats.best_fitness ++ [best.fitness],
        avg_fitness: stats.avg_fitness ++ [avg_fitness],
        std_fitness: stats.std_fitness ++ [variance],
        population_sizes: stats.population_sizes ++ [length(population)],
        diversity: diversity
    }
  end

  @doc """
  Marks the end of the evolution and calculates the duration.
  """
  def finalize(stats) do
    end_time = DateTime.utc_now()
    duration = DateTime.diff(end_time, stats.start_time, :millisecond) / 1000

    %{stats | end_time: end_time, duration: duration}
  end

  @doc """
  Returns statistics for a specific generation.
  """
  def for_generation(stats, generation) do
    if generation < 0 || generation >= stats.generations do
      nil
    else
      %{
        generation: generation,
        best_fitness: Enum.at(stats.best_fitness, generation),
        avg_fitness: Enum.at(stats.avg_fitness, generation),
        std_fitness: Enum.at(stats.std_fitness, generation),
        population_size: Enum.at(stats.population_sizes, generation),
        diversity:
          if(length(stats.diversity) > 0, do: Enum.at(stats.diversity, generation), else: nil)
      }
    end
  end

  @doc """
  Plots fitness progress over generations.

  Requires `gnuplot` to be installed on the system.
  """
  def plot_fitness(stats, options \\ []) do
    filename = Keyword.get(options, :filename, "fitness.png")
    title = Keyword.get(options, :title, "Fitness Progress")

    data_file = Path.join(System.tmp_dir(), "fitness_data.txt")

    data =
      for i <- 0..(length(stats.best_fitness) - 1) do
        "#{i}\t#{Enum.at(stats.best_fitness, i)}\t#{Enum.at(stats.avg_fitness, i)}\t#{Enum.at(stats.std_fitness, i)}"
      end

    File.write!(data_file, Enum.join(data, "\n"))

    gnuplot_script = """
    set terminal png size 800,600
    set output "#{filename}"
    set title "#{title}"
    set xlabel "Generation"
    set ylabel "Fitness"
    set grid
    plot "#{data_file}" using 1:2 title "Best Fitness" with lines lw 2, \
         "#{data_file}" using 1:3 title "Average Fitness" with lines lw 1, \
         "#{data_file}" using 1:4 title "Standard Deviation" with lines lw 1
    """

    script_file = Path.join(System.tmp_dir(), "fitness_plot.gp")
    File.write!(script_file, gnuplot_script)

    System.cmd("gnuplot", [script_file])

    File.rm(data_file)
    File.rm(script_file)

    {:ok, filename}
  end

  @doc """
  Generates a summary report of the evolution.
  """
  def summary(stats) do
    """
    Evolution Summary
    ----------------
    Total Generations: #{stats.generations}
    Best Fitness: #{List.last(stats.best_fitness)}
    Average Fitness (last generation): #{List.last(stats.avg_fitness)}
    Standard Deviation (last generation): #{List.last(stats.std_fitness)}
    Duration: #{stats.duration} seconds
    Population Size: #{List.last(stats.population_sizes)}
    """
  end

  @doc """
  Saves statistics to a JSON file.
  """
  @spec save(t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def save(stats, filename) do
    case Jason.encode(stats, pretty: true) do
      {:ok, json} -> File.write(filename, json)
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Loads statistics from a JSON file.
  """
  @spec load(String.t()) :: {:ok, t()} | {:error, term()}
  def load(filename) do
    with {:ok, json} <- File.read(filename),
         {:ok, map} <- Jason.decode(json) do
      {:ok, struct(Tyrex.Statistics, map)}
    end
  end

  defp calculate_variance(values) do
    n = length(values)

    if n <= 1 do
      0.0
    else
      mean = Enum.sum(values) / n
      squared_diff_sum = Enum.sum(Enum.map(values, fn x -> :math.pow(x - mean, 2) end))
      squared_diff_sum / (n - 1)
    end
  end
end
