defmodule SecretConfigTest do
  use ExUnit.Case
  doctest SecretConfig

  test "greets the world" do
    assert SecretConfig.hello() == :world
  end
end
