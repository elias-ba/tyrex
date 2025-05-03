defmodule TyrexTest do
  use ExUnit.Case
  doctest Tyrex

  test "greets the world" do
    assert Tyrex.hello() == :world
  end
end
