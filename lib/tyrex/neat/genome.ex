defmodule Tyrex.NEAT.Genome do
  @moduledoc """
  Genome representation for NEAT.

  A genome consists of genes (connections) between nodes in a neural network.
  Each gene has an innovation number that identifies it across all genomes.
  """

  alias Tyrex.NEAT.InnovationCounter

  @type gene :: %{
          innovation: integer(),
          in_node: integer(),
          out_node: integer(),
          weight: float(),
          enabled: boolean()
        }

  @type t :: %__MODULE__{
          genes: [gene()],
          nodes: MapSet.t(),
          fitness: number(),
          adjusted_fitness: number(),
          species_id: integer() | nil
        }

  defstruct [
    :genes,
    :nodes,
    fitness: 0,
    adjusted_fitness: 0,
    species_id: nil
  ]

  @doc """
  Creates a new genome with the minimal topology.

  This creates a fully connected network between input and output nodes,
  with no hidden nodes.

  ## Options

  * `:inputs` - Number of input nodes (default: 3)
  * `:outputs` - Number of output nodes (default: 1)
  * `:bias` - Whether to include a bias node (default: true)
  """
  def create(opts \\ []) do
    inputs = Keyword.get(opts, :inputs, 3)
    outputs = Keyword.get(opts, :outputs, 1)
    bias = Keyword.get(opts, :bias, true)

    input_nodes = 0..(inputs - 1)

    input_nodes =
      if bias do
        Enum.to_list(input_nodes) ++ [inputs]
      else
        Enum.to_list(input_nodes)
      end

    num_inputs = length(input_nodes)
    output_nodes = num_inputs..(num_inputs + outputs - 1)

    nodes = MapSet.new(input_nodes ++ Enum.to_list(output_nodes))

    genes =
      for in_node <- input_nodes, out_node <- output_nodes do
        %{
          innovation: InnovationCounter.get_innovation(in_node, out_node),
          in_node: in_node,
          out_node: out_node,
          weight: :rand.normal() * 2.0,
          enabled: true
        }
      end

    %__MODULE__{
      genes: genes,
      nodes: nodes
    }
  end

  @doc """
  Calculates the compatibility distance between two genomes.

  This is used to determine whether genomes belong to the same species.

  ## Options

  * `:c1` - Coefficient for excess genes (default: 1.0)
  * `:c2` - Coefficient for disjoint genes (default: 1.0)
  * `:c3` - Coefficient for weight differences (default: 0.4)
  """
  def distance(genome1, genome2, opts \\ []) do
    c1 = Keyword.get(opts, :c1, 1.0)
    c2 = Keyword.get(opts, :c2, 1.0)
    c3 = Keyword.get(opts, :c3, 0.4)

    g1_by_innov = Map.new(genome1.genes, fn g -> {g.innovation, g} end)
    g2_by_innov = Map.new(genome2.genes, fn g -> {g.innovation, g} end)

    g1_innovations = MapSet.new(Map.keys(g1_by_innov))
    g2_innovations = MapSet.new(Map.keys(g2_by_innov))

    max_innov1 = if Enum.empty?(g1_innovations), do: 0, else: Enum.max(g1_innovations)
    max_innov2 = if Enum.empty?(g2_innovations), do: 0, else: Enum.max(g2_innovations)

    matching = MapSet.intersection(g1_innovations, g2_innovations)

    # Disjoint genes are in one genome but not the other, and their innovation
    # numbers are less than the maximum innovation number in the other genome
    disjoint1 =
      MapSet.new(
        Enum.filter(g1_innovations, fn i -> i not in g2_innovations and i <= max_innov2 end)
      )

    disjoint2 =
      MapSet.new(
        Enum.filter(g2_innovations, fn i -> i not in g1_innovations and i <= max_innov1 end)
      )

    disjoint = MapSet.union(disjoint1, disjoint2)

    # Excess genes are in one genome but not the other, and their innovation
    # numbers are greater than the maximum innovation number in the other genome
    excess1 =
      MapSet.new(
        Enum.filter(g1_innovations, fn i -> i not in g2_innovations and i > max_innov2 end)
      )

    excess2 =
      MapSet.new(
        Enum.filter(g2_innovations, fn i -> i not in g1_innovations and i > max_innov1 end)
      )

    excess = MapSet.union(excess1, excess2)

    weight_diffs =
      Enum.map(matching, fn i ->
        g1 = Map.get(g1_by_innov, i)
        g2 = Map.get(g2_by_innov, i)
        abs(g1.weight - g2.weight)
      end)

    avg_weight_diff =
      if Enum.empty?(weight_diffs), do: 0.0, else: Enum.sum(weight_diffs) / length(weight_diffs)

    n = max(1, max(length(genome1.genes), length(genome2.genes)))

    c1 * MapSet.size(excess) / n + c2 * MapSet.size(disjoint) / n + c3 * avg_weight_diff
  end

  @doc """
  Performs crossover between two genomes.

  The more fit parent's genes are inherited if they don't match.
  For matching genes, they are randomly inherited from either parent.
  """
  def crossover(parent1, parent2) do
    {parent1, parent2} =
      if parent1.fitness >= parent2.fitness, do: {parent1, parent2}, else: {parent2, parent1}

    p1_by_innov = Map.new(parent1.genes, fn g -> {g.innovation, g} end)
    p2_by_innov = Map.new(parent2.genes, fn g -> {g.innovation, g} end)

    p1_innovations = Map.keys(p1_by_innov)
    p2_innovations = Map.keys(p2_by_innov)

    matching = Enum.filter(p1_innovations, fn i -> i in p2_innovations end)

    # Create child genes
    # Matching genes - inherited randomly from either parent
    # Disjoint and excess genes - inherited from the more fit parent
    child_genes =
      Enum.map(matching, fn i ->
        if :rand.uniform() < 0.5 do
          Map.get(p1_by_innov, i)
        else
          Map.get(p2_by_innov, i)
        end
      end) ++
        Enum.map(Enum.filter(p1_innovations, fn i -> i not in p2_innovations end), fn i ->
          Map.get(p1_by_innov, i)
        end)

    nodes = collect_nodes(child_genes)

    %__MODULE__{
      genes: child_genes,
      nodes: nodes
    }
  end

  @doc """
  Mutates a genome by adding a new node.

  This works by disabling an existing connection and adding a new node
  with two new connections.
  """
  def add_node_mutation(genome) do
    if Enum.empty?(genome.genes) do
      genome
    else
      enabled_genes = Enum.filter(genome.genes, & &1.enabled)

      if Enum.empty?(enabled_genes) do
        genome
      else
        gene = Enum.random(enabled_genes)

        new_node = InnovationCounter.get_node_innovation()

        in_to_new = %{
          innovation: InnovationCounter.get_innovation(gene.in_node, new_node),
          in_node: gene.in_node,
          out_node: new_node,
          # Weight to the new node is 1.0
          weight: 1.0,
          enabled: true
        }

        new_to_out = %{
          innovation: InnovationCounter.get_innovation(new_node, gene.out_node),
          in_node: new_node,
          out_node: gene.out_node,
          # This preserves the original behavior
          weight: gene.weight,
          enabled: true
        }

        modified_genes =
          Enum.map(genome.genes, fn g ->
            if g.innovation == gene.innovation do
              %{g | enabled: false}
            else
              g
            end
          end)

        new_genes = [in_to_new, new_to_out | modified_genes]
        new_nodes = MapSet.put(genome.nodes, new_node)

        %{genome | genes: new_genes, nodes: new_nodes}
      end
    end
  end

  @doc """
  Mutates a genome by adding a new connection between existing nodes.
  """
  def add_connection_mutation(genome, opts \\ []) do
    input_count = Keyword.get(opts, :inputs, 0)
    output_count = Keyword.get(opts, :outputs, 0)

    input_nodes = Enum.filter(genome.nodes, fn n -> n < input_count end)

    output_nodes =
      Enum.filter(genome.nodes, fn n -> n >= input_count && n < input_count + output_count end)

    hidden_nodes = Enum.filter(genome.nodes, fn n -> n >= input_count + output_count end)

    existing_connections = MapSet.new(Enum.map(genome.genes, fn g -> {g.in_node, g.out_node} end))

    pair = find_valid_connection(input_nodes, hidden_nodes, output_nodes, existing_connections)

    case pair do
      nil ->
        genome

      {in_node, out_node} ->
        new_gene = %{
          innovation: InnovationCounter.get_innovation(in_node, out_node),
          in_node: in_node,
          out_node: out_node,
          weight: :rand.normal() * 2.0,
          enabled: true
        }

        %{genome | genes: [new_gene | genome.genes]}
    end
  end

  @doc """
  Mutates a genome's connection weights.

  ## Options

  * `:perturbation_rate` - Rate of weight perturbation vs. replacement (default: 0.9)
  * `:perturbation_power` - Power of perturbation (default: 0.5)
  """
  def mutate_weights(genome, opts \\ []) do
    perturbation_rate = Keyword.get(opts, :perturbation_rate, 0.9)
    perturbation_power = Keyword.get(opts, :perturbation_power, 0.5)

    new_genes =
      Enum.map(genome.genes, fn gene ->
        if :rand.uniform() < perturbation_rate do
          %{gene | weight: gene.weight + :rand.normal() * perturbation_power}
        else
          %{gene | weight: :rand.normal() * 2.0}
        end
      end)

    %{genome | genes: new_genes}
  end

  @doc """
  Mutates a genome by toggling the enabled status of a connection.
  """
  def toggle_connection_mutation(genome) do
    if Enum.empty?(genome.genes) do
      genome
    else
      gene = Enum.random(genome.genes)

      modified_genes =
        Enum.map(genome.genes, fn g ->
          if g.innovation == gene.innovation do
            %{g | enabled: !g.enabled}
          else
            g
          end
        end)

      %{genome | genes: modified_genes}
    end
  end

  @doc """
  Applies all mutations to a genome based on probabilities.

  ## Options

  * `:add_node_rate` - Probability of adding a node (default: 0.03)
  * `:add_connection_rate` - Probability of adding a connection (default: 0.05)
  * `:weight_mutation_rate` - Probability of mutating weights (default: 0.8)
  * `:toggle_connection_rate` - Probability of toggling a connection (default: 0.01)
  """
  def mutate(genome, opts \\ []) do
    add_node_rate = Keyword.get(opts, :add_node_rate, 0.03)
    add_connection_rate = Keyword.get(opts, :add_connection_rate, 0.05)
    weight_mutation_rate = Keyword.get(opts, :weight_mutation_rate, 0.8)
    toggle_connection_rate = Keyword.get(opts, :toggle_connection_rate, 0.01)

    genome
    |> maybe_apply(add_node_rate, &add_node_mutation/1)
    |> maybe_apply(add_connection_rate, &add_connection_mutation/2, [opts])
    |> maybe_apply(weight_mutation_rate, &mutate_weights/1)
    |> maybe_apply(toggle_connection_rate, &toggle_connection_mutation/1)
  end

  defp maybe_apply(genome, probability, mutation_fn, args \\ []) do
    if :rand.uniform() < probability do
      apply(mutation_fn, [genome | args])
    else
      genome
    end
  end

  defp collect_nodes(genes) do
    Enum.reduce(genes, MapSet.new(), fn gene, acc ->
      acc
      |> MapSet.put(gene.in_node)
      |> MapSet.put(gene.out_node)
    end)
  end

  defp find_valid_connection(input_nodes, hidden_nodes, output_nodes, existing_connections) do
    find_connection_between(hidden_nodes, output_nodes, existing_connections) ||
      find_connection_between(input_nodes, hidden_nodes, existing_connections) ||
      find_connection_between(input_nodes, output_nodes, existing_connections) ||
      find_connection_between(hidden_nodes, hidden_nodes, existing_connections)
  end

  defp find_connection_between(sources, targets, existing_connections) do
    if Enum.empty?(sources) || Enum.empty?(targets) do
      nil
    else
      pairs = for source <- sources, target <- targets, do: {source, target}

      valid_pairs =
        Enum.filter(pairs, fn {source, target} ->
          source != target && {source, target} not in existing_connections
        end)

      if Enum.empty?(valid_pairs) do
        nil
      else
        Enum.random(valid_pairs)
      end
    end
  end
end
