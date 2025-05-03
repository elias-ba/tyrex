defmodule Tyrex.CheckpointManager do
  @moduledoc """
  Manager for saving and loading evolution checkpoints.
  """
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Saves a checkpoint of the current evolution state.
  """
  def save_checkpoint(run_id, state) do
    GenServer.call(__MODULE__, {:save, run_id, state})
  end

  @doc """
  Loads a checkpoint for a specific run.
  """
  def load_checkpoint(run_id) do
    GenServer.call(__MODULE__, {:load, run_id})
  end

  @doc """
  Lists all available checkpoints.
  """
  def list_checkpoints do
    GenServer.call(__MODULE__, :list)
  end

  @doc """
  Deletes a checkpoint.
  """
  def delete_checkpoint(run_id) do
    GenServer.call(__MODULE__, {:delete, run_id})
  end

  @impl true
  def init(_) do
    # Create checkpoint directory if it doesn't exist
    checkpoint_dir = checkpoint_directory()
    File.mkdir_p!(checkpoint_dir)

    {:ok, %{}}
  end

  @impl true
  def handle_call({:save, run_id, state}, _from, manager_state) do
    # Serialize the state
    binary = :erlang.term_to_binary(state)

    # Save to file
    filename = checkpoint_filename(run_id)
    File.write!(filename, binary)

    {:reply, :ok, manager_state}
  end

  @impl true
  def handle_call({:load, run_id}, _from, manager_state) do
    filename = checkpoint_filename(run_id)

    if File.exists?(filename) do
      # Load and deserialize
      binary = File.read!(filename)
      state = :erlang.binary_to_term(binary)

      {:reply, {:ok, state}, manager_state}
    else
      {:reply, {:error, :not_found}, manager_state}
    end
  end

  @impl true
  def handle_call(:list, _from, manager_state) do
    checkpoint_dir = checkpoint_directory()

    checkpoints =
      case File.ls(checkpoint_dir) do
        {:ok, files} ->
          files
          |> Enum.filter(&String.ends_with?(&1, ".checkpoint"))
          |> Enum.map(fn filename ->
            run_id = String.replace(filename, ".checkpoint", "")
            stats = get_checkpoint_stats(Path.join(checkpoint_dir, filename))
            {run_id, stats}
          end)

        {:error, _} ->
          []
      end

    {:reply, checkpoints, manager_state}
  end

  @impl true
  def handle_call({:delete, run_id}, _from, manager_state) do
    filename = checkpoint_filename(run_id)

    if File.exists?(filename) do
      File.rm!(filename)
      {:reply, :ok, manager_state}
    else
      {:reply, {:error, :not_found}, manager_state}
    end
  end

  @doc """
  Gets the directory where checkpoints are stored.
  """
  def checkpoint_directory do
    Application.get_env(
      :genetic_ex,
      :checkpoint_dir,
      Path.join(System.tmp_dir(), "genetic_ex/checkpoints")
    )
  end

  @doc """
  Gets the filename for a checkpoint.
  """
  def checkpoint_filename(run_id) do
    Path.join(checkpoint_directory(), "#{run_id}.checkpoint")
  end

  defp get_checkpoint_stats(filename) do
    case File.stat(filename) do
      {:ok, %File.Stat{size: size, mtime: mtime}} ->
        %{
          size: size,
          timestamp: mtime
        }

      _ ->
        %{}
    end
  end

  @doc """
  Saves a checkpoint to a custom location.
  """
  def save_to_file(state, filename) do
    # Serialize the state
    binary = :erlang.term_to_binary(state)

    # Save to file
    File.write!(filename, binary)

    :ok
  end

  @doc """
  Loads a checkpoint from a custom location.
  """
  def load_from_file(filename) do
    if File.exists?(filename) do
      # Load and deserialize
      binary = File.read!(filename)
      state = :erlang.binary_to_term(binary)

      {:ok, state}
    else
      {:error, :not_found}
    end
  end
end
