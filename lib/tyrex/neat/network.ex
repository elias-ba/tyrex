defmodule Tyrex.NEAT.Network do
  @moduledoc """
  Neural network implementation for NEAT.

  This module handles the creation and activation of neural networks
  from NEAT genomes.
  """

  @doc """
  Creates a neural network from a genome.

  Returns a network structure that can be activated with inputs.
  """
  def create(genome) do
    %{
      genome: genome,
      nodes: build_node_map(genome)
    }
  end

  @doc """
  Activates the neural network with the given inputs.

  Returns the output values.

  ## Options

  * `:activation_fn` - Activation function to use (default: sigmoid)
  """
  def activate(network, inputs, opts \\ []) do
    activation_fn = Keyword.get(opts, :activation_fn, &sigmoid/1)

    node_values = initialize_inputs(network, inputs)

    sorted_connections = topological_sort(network)

    node_values = process_connections(sorted_connections, node_values, activation_fn)

    extract_outputs(network, node_values)
  end

  defp build_node_map(genome) do
    # Group nodes by type (assuming the node IDs follow a convention)
    # This is a simplified implementation - in a real system, node types
    # would be tracked during genome creation

    # For now, we'll use a simple heuristic:
    # - Nodes that are only sources are inputs
    # - Nodes that are only targets are outputs
    # - Nodes that are both are hidden
    sources = MapSet.new(Enum.map(genome.genes, & &1.in_node))
    targets = MapSet.new(Enum.map(genome.genes, & &1.out_node))

    inputs = MapSet.difference(sources, targets)
    outputs = MapSet.difference(targets, sources)
    hidden = MapSet.intersection(sources, targets)

    %{
      inputs: inputs,
      outputs: outputs,
      hidden: hidden
    }
  end

  defp initialize_inputs(network, inputs) do
    input_nodes = MapSet.to_list(network.nodes.inputs)

    if length(inputs) != length(input_nodes) do
      raise "Number of inputs (#{length(inputs)}) does not match number of input nodes (#{length(input_nodes)})"
    end

    Enum.zip(input_nodes, inputs)
    |> Enum.into(%{})
  end

  defp topological_sort(network) do
    # This is a simplified topological sort that assumes no cycles
    # In a real implementation, you would need to handle cycles

    genes_by_source = Enum.group_by(network.genome.genes, & &1.in_node)

    sorted = []
    visited = MapSet.new()

    input_nodes = MapSet.to_list(network.nodes.inputs)

    {sorted, _} =
      Enum.reduce(input_nodes, {sorted, visited}, fn node, {sorted_acc, visited_acc} ->
        visit_node(node, genes_by_source, sorted_acc, visited_acc)
      end)

    Enum.filter(sorted, fn gene -> gene.enabled end)
  end

  defp visit_node(node, genes_by_source, sorted, visited) do
    if MapSet.member?(visited, node) do
      {sorted, visited}
    else
      visited = MapSet.put(visited, node)

      outgoing = Map.get(genes_by_source, node, [])

      {sorted, visited} =
        Enum.reduce(outgoing, {sorted, visited}, fn gene, {sorted_acc, visited_acc} ->
          {sorted_next, visited_next} =
            visit_node(gene.out_node, genes_by_source, sorted_acc, visited_acc)

          {[gene | sorted_next], visited_next}
        end)

      {sorted, visited}
    end
  end

  defp process_connections(connections, node_values, activation_fn) do
    Enum.reduce(connections, node_values, fn gene, values ->
      in_val = Map.get(values, gene.in_node, 0.0)

      current_out = Map.get(values, gene.out_node, 0.0)

      new_out = current_out + in_val * gene.weight

      Map.put(values, gene.out_node, activation_fn.(new_out))
    end)
  end

  defp extract_outputs(network, node_values) do
    output_nodes = MapSet.to_list(network.nodes.outputs)

    Enum.map(output_nodes, fn node ->
      Map.get(node_values, node, 0.0)
    end)
  end

  defp sigmoid(x) do
    1.0 / (1.0 + :math.exp(-4.9 * x))
  end
end
