defmodule Tyrex.NEAT.InnovationCounter do
  @moduledoc """
  A server for tracking innovation numbers in NEAT.

  Innovation numbers are used to identify genes (connections) uniquely across
  all genomes in the population. This is necessary for proper crossover
  and measuring compatibility distance between genomes.
  """
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Gets a new innovation number for a connection between two nodes.

  If the connection already exists, returns the existing innovation number.
  """
  def get_innovation(in_node, out_node) do
    GenServer.call(__MODULE__, {:get_innovation, in_node, out_node})
  end

  @doc """
  Gets a new innovation number for a new node.
  """
  def get_node_innovation do
    GenServer.call(__MODULE__, :get_node_innovation)
  end

  @doc """
  Resets all innovation numbers.
  """
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  @impl true
  def init(_) do
    {:ok, %{innovations: %{}, next_innovation: 1, next_node: 0}}
  end

  @doc """
  Gets the current state of the innovation counter.
  """
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:set_state, new_state}, _from, _state) do
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:get_innovation, in_node, out_node}, _from, state) do
    key = {in_node, out_node}

    case Map.get(state.innovations, key) do
      nil ->
        innovation = state.next_innovation
        innovations = Map.put(state.innovations, key, innovation)

        {:reply, innovation, %{state | innovations: innovations, next_innovation: innovation + 1}}

      existing_innovation ->
        {:reply, existing_innovation, state}
    end
  end

  @impl true
  def handle_call(:get_node_innovation, _from, state) do
    next_node = state.next_node + 1

    {:reply, next_node, %{state | next_node: next_node}}
  end

  @impl true
  def handle_call(:reset, _from, _state) do
    {:reply, :ok, %{innovations: %{}, next_innovation: 1, next_node: 0}}
  end

  @doc """
  Sets the state of the innovation counter.

  Useful for loading a checkpoint.
  """
  def set_state(state) do
    GenServer.call(__MODULE__, {:set_state, state})
  end
end
