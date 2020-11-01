defmodule SecretConfigTest do
  @moduledoc false
  use ExUnit.Case, async: false
  doctest SecretConfig

  describe "#fetch" do
    setup do
      SecretConfig.push("path/to/fetch", "value123")
      :ok
    end

    test "fetches value from ssm parameter store" do
      assert "value123" == SecretConfig.fetch("path/to/fetch")
    end

    test "returns default value for a non existent key" do
      assert "default" == SecretConfig.fetch("non_existing/fetch", "default")
    end
  end

  describe "#fetch!" do
    setup do
      SecretConfig.push("path/to/fetch", "value123")
      :ok
    end

    test "fetches value from ssm parameter store" do
      assert "value123" == SecretConfig.fetch!("path/to/fetch")
    end

    test "raises error for a non existent key" do
      assert_raise RuntimeError, fn ->
        SecretConfig.fetch!("non_existing/fetch")
      end
    end
  end

  describe "#delete" do
    setup do
      SecretConfig.push("path/to/delete", "value123")
      :ok
    end

    test "deletes value from ssm parameter store" do
      assert "/test/app_name/path/to/delete" == SecretConfig.delete("path/to/delete")
    end
  end

  describe "#push" do
    test "pushes to ssm parameter store" do
      assert "/test/app_name/path/to/push" == SecretConfig.push("path/to/push", "value123")
    end
  end

  describe "#refresh" do
    setup do
      SecretConfig.push("path/to/refresh", "value123")
      :ok
    end

    test "pushes to ssm parameter store" do
      {:file, gen_state} = :sys.get_state(SecretConfig.Cache.Server)

      assert Map.has_key?(gen_state, "/test/app_name/path/to/refresh")
    end
  end
end
