defmodule SecretConfigTest do
  @moduledoc false
  use ExUnit.Case, async: false
  doctest SecretConfig

  describe "#push" do
    setup do
      SecretConfig.push("path/to/parameter", "value123")
      :ok
    end

    test "fetches value from ssm parameter store" do
      assert "value123" == SecretConfig.fetch("path/to/parameter")
    end

    test "returns default value for non existent key" do
      assert "default" == SecretConfig.fetch("non_existing/parameter", "default")
    end
  end

  describe "#delete" do
    setup do
      SecretConfig.push("path/to/parameter/delete", "value123")
      :ok
    end

    test "deletes value from ssm parameter store" do
      assert "/test/portfolio_monitor/path/to/parameter/delete" == SecretConfig.delete("path/to/parameter/delete")
      assert [], SecretConfig.fetch("path/to/parameter/delete")
    end
  end
end

