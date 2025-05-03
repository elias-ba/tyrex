defmodule Tyrex.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Tyrex.NEAT.InnovationRegistry},
      {Tyrex.NEAT.InnovationCounter, []},
      {Tyrex.CheckpointManager, []},
      {DynamicSupervisor, strategy: :one_for_one, name: Tyrex.EvolutionSupervisor}
    ]

    opts = [strategy: :one_for_one, name: Tyrex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
