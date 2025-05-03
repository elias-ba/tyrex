defmodule Tyrex.Statistics do
  @moduledoc """
  Statistics for tracking evolution progress.
  """

  defstruct [
    :start_time,
    :end_time,
    generations: 0,
    best_individual: nil,
    best_fitness: [],
    average_fitness: [],
    population_sizes: [],
    diversity: [],
    duration: 0
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

    # Calculate diversity if a distance function is provided
    diversity =
      case Keyword.get(opts, :distance_fn) do
        nil ->
          stats.diversity

        distance_fn ->
          current_diversity = Tyrex.Population.diversity(population, distance_fn)
          stats.diversity ++ [current_diversity]
      end

    # Update stats
    %{
      stats
      | generations: generation,
        best_individual: best,
        best_fitness: stats.best_fitness ++ [best.fitness],
        average_fitness: stats.average_fitness ++ [avg_fitness],
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
        average_fitness: Enum.at(stats.average_fitness, generation),
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

    # Create temporary data file
    data_file = Path.join(System.tmp_dir(), "fitness_data.txt")

    # Write data to temporary file
    data =
      for i <- 0..(length(stats.best_fitness) - 1) do
        "#{i}\t#{Enum.at(stats.best_fitness, i)}\t#{Enum.at(stats.average_fitness, i)}"
      end

    File.write!(data_file, Enum.join(data, "\n"))

    # Create gnuplot script
    gnuplot_script = """
    set terminal png size 800,600
    set output "#{filename}"
    set title "#{title}"
    set xlabel "Generation"
    set ylabel "Fitness"
    set grid
    plot "#{data_file}" using 1:2 title "Best Fitness" with lines lw 2, \
         "#{data_file}" using 1:3 title "Average Fitness" with lines lw 1
    """

    script_file = Path.join(System.tmp_dir(), "fitness_plot.gp")
    File.write!(script_file, gnuplot_script)

    # Execute gnuplot
    System.cmd("gnuplot", [script_file])

    # Clean up
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
    Average Fitness (last generation): #{List.last(stats.average_fitness)}
    Duration: #{stats.duration} seconds
    Population Size: #{List.last(stats.population_sizes)}
    """
  end

  @doc """
  Saves statistics to a JSON file.
  """
  def save(stats, filename) do
    # Convert stats to a map
    stats_map = Map.from_struct(stats)

    # Serialize to JSON
    json = Poison.encode!(stats_map, pretty: true)

    # Write to file
    File.write!(filename, json)

    {:ok, filename}
  end

  @doc """
  Loads statistics from a JSON file.
  """
  def load(filename) do
    # Read from file
    {:ok, json} = File.read(filename)

    # Deserialize from JSON
    {:ok, stats_map} = Poison.decode(json)

    # Convert to struct
    stats = struct(Tyrex.Statistics, Map.new(stats_map, fn {k, v} -> {String.to_atom(k), v} end))

    {:ok, stats}
  end
end
