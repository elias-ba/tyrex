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
    # Create a map of nodes and their type (input, hidden, output)
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

    # Convert inputs to a map of node values
    node_values = initialize_inputs(network, inputs)

    # Sort genes by depth to ensure proper feed-forward activation
    sorted_connections = topological_sort(network)

    # Activate the network
    node_values = process_connections(sorted_connections, node_values, activation_fn)

    # Extract output values
    extract_outputs(network, node_values)
  end

  # Helper function to build a map of nodes and their type
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

  # Helper function to initialize inputs
  defp initialize_inputs(network, inputs) do
    input_nodes = MapSet.to_list(network.nodes.inputs)

    if length(inputs) != length(input_nodes) do
      raise "Number of inputs (#{length(inputs)}) does not match number of input nodes (#{length(input_nodes)})"
    end

    # Create a map of input node values
    Enum.zip(input_nodes, inputs)
    |> Enum.into(%{})
  end

  # Helper function to sort connections in topological order
  defp topological_sort(network) do
    # This is a simplified topological sort that assumes no cycles
    # In a real implementation, you would need to handle cycles

    # Group genes by their source node
    genes_by_source = Enum.group_by(network.genome.genes, & &1.in_node)

    # Recursively build the sorted connections
    sorted = []
    visited = MapSet.new()

    # Start with input nodes
    input_nodes = MapSet.to_list(network.nodes.inputs)

    # Visit each input node
    {sorted, _} =
      Enum.reduce(input_nodes, {sorted, visited}, fn node, {sorted_acc, visited_acc} ->
        visit_node(node, genes_by_source, sorted_acc, visited_acc)
      end)

    # Return only enabled connections
    Enum.filter(sorted, fn gene -> gene.enabled end)
  end

  # Helper function for topological sort
  defp visit_node(node, genes_by_source, sorted, visited) do
    if MapSet.member?(visited, node) do
      {sorted, visited}
    else
      visited = MapSet.put(visited, node)

      # Get outgoing connections from this node
      outgoing = Map.get(genes_by_source, node, [])

      # Visit each target node
      {sorted, visited} =
        Enum.reduce(outgoing, {sorted, visited}, fn gene, {sorted_acc, visited_acc} ->
          {sorted_next, visited_next} =
            visit_node(gene.out_node, genes_by_source, sorted_acc, visited_acc)

          {[gene | sorted_next], visited_next}
        end)

      {sorted, visited}
    end
  end

  # Helper function to process connections
  defp process_connections(connections, node_values, activation_fn) do
    Enum.reduce(connections, node_values, fn gene, values ->
      # Get the input value
      in_val = Map.get(values, gene.in_node, 0.0)

      # Get the current output value
      current_out = Map.get(values, gene.out_node, 0.0)

      # Calculate the new output value
      new_out = current_out + in_val * gene.weight

      # Update the node values
      Map.put(values, gene.out_node, activation_fn.(new_out))
    end)
  end

  # Helper function to extract outputs
  defp extract_outputs(network, node_values) do
    output_nodes = MapSet.to_list(network.nodes.outputs)

    # Get the value for each output node
    Enum.map(output_nodes, fn node ->
      Map.get(node_values, node, 0.0)
    end)
  end

  # Default activation function (sigmoid)
  defp sigmoid(x) do
    1.0 / (1.0 + :math.exp(-4.9 * x))
  end
end
