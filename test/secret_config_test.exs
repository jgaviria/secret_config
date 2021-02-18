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
      assert "value123" == SecretConfig.fetch("path/to/fetch", nil)
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
      assert "path/to/delete" == SecretConfig.delete("path/to/delete")
    end
  end

  describe "#push" do
    test "pushes to ssm parameter store" do
      assert "path/to/push" == SecretConfig.push("path/to/push", "value123")
    end
  end

  describe "#refresh" do
    setup do
      SecretConfig.set_env("/test/app_name")
      SecretConfig.push("path/to/refresh", "value123")
      :ok
    end

    test "pushes to ssm parameter store" do
      {:local, _prefix, gen_state} = :sys.get_state(SecretConfig.Cache.Server)

      assert Map.has_key?(gen_state, "/test/app_name/path/to/refresh")
    end
  end

  describe "#imports" do
    test "pulls imports respecting overrides" do
      SecretConfig.set_env("/test/other_application")
      :timer.sleep(5000)
      GenServer.cast(SecretConfig.Cache.Server, {:refresh})

      {:local, _prefix, gen_state} = :sys.get_state(SecretConfig.Cache.Server)

      assert Map.has_key?(gen_state, "/test/other_application/symmetric_encryption/iv")
      assert Map.has_key?(gen_state, "/test/other_application/symmetric_encryption/key")
      assert Map.has_key?(gen_state, "/test/other_application/symmetric_encryption/version")

      assert "global_iv" == SecretConfig.fetch!("symmetric_encryption/iv")
      assert "global_key" == SecretConfig.fetch!("symmetric_encryption/key")
      assert "override_1" == SecretConfig.fetch!("symmetric_encryption/version")
    end

    test "pulls nested imports respecting overrides" do
      SecretConfig.set_env("/test/other_other_application")
      :timer.sleep(5000)
      GenServer.cast(SecretConfig.Cache.Server, {:refresh})

      {:local, _prefix, gen_state} = :sys.get_state(SecretConfig.Cache.Server)

      assert Map.has_key?(gen_state, "/test/other_other_application/symmetric_encryption/iv")
      assert Map.has_key?(gen_state, "/test/other_other_application/symmetric_encryption/key")
      assert Map.has_key?(gen_state, "/test/other_other_application/symmetric_encryption/version")

      assert "global_iv" == SecretConfig.fetch!("symmetric_encryption/iv")
      assert "global_key" == SecretConfig.fetch!("symmetric_encryption/key")
      assert "override_2" == SecretConfig.fetch!("symmetric_encryption/version")
    end
  end

  # Only run when pointing to the ssm parameter store
  describe "ssm" do
    @tag :ssm_test
    test "#push, key?, delete, fetch" do
      #push
      SecretConfig.push("customer_1/secret_1", "cust_1_secret_1")
      SecretConfig.push("customer_1/secret_2", "cust_1_secret_2")
      SecretConfig.push("customer_2/secret_1", "cust_2_secret_1")
      SecretConfig.push("customer_2/secret_2", "cust_2_secret_2")
      :timer.sleep(5000)
      GenServer.cast(SecretConfig.Cache.Server, {:refresh})

      #key?
      assert SecretConfig.key?("customer_1/secret_1")
      assert SecretConfig.key?("customer_1/secret_2")
      assert SecretConfig.key?("customer_2/secret_1")
      assert SecretConfig.key?("customer_2/secret_2")

      #fetch!
      assert SecretConfig.fetch!("customer_1/secret_1")
      assert SecretConfig.fetch!("customer_1/secret_2")
      assert SecretConfig.fetch!("customer_2/secret_1")
      assert SecretConfig.fetch!("customer_2/secret_2")

      #delete
      SecretConfig.delete("customer_1/secret_1")
      SecretConfig.delete("customer_1/secret_2")
      SecretConfig.delete("customer_2/secret_1")
      SecretConfig.delete("customer_2/secret_2")
      :timer.sleep(5000)
      GenServer.cast(SecretConfig.Cache.Server, {:refresh})

      refute SecretConfig.key?("customer_1/secret_1")
      refute SecretConfig.key?("customer_1/secret_2")
      refute SecretConfig.key?("customer_2/secret_1")
      refute SecretConfig.key?("customer_2/secret_2")
    end

    @tag :ssm_test
    test "#imports" do
      # set params under /test/app_name/
      SecretConfig.set_env("/test/app_name/batch")
      SecretConfig.push("__import__", "/base/config/batch")
      SecretConfig.push("shared_key_1", "override_key_1")
      SecretConfig.push("shared_key_2", "override_key_2")

      # set 1 level imports
      SecretConfig.set_env("/base/config/batch")
      SecretConfig.push("shared_key_1", "base_key_1")
      SecretConfig.push("shared_key_2", "base_key_2")
      SecretConfig.push("shared_key_3", "base_key_3")
      SecretConfig.push("__import__", "/global/config/batch")

      # set 2 level imports
      SecretConfig.set_env("/global/config/batch")
      SecretConfig.push("shared_key_4", "global_key_4")
      SecretConfig.push("shared_key_5", "global_key_5")
      SecretConfig.push("shared_key_6", "global_key_6")

      # put back original prefix and refresh local registry
      SecretConfig.set_env("/test/app_name/batch")
      :timer.sleep(5000)
      GenServer.cast(SecretConfig.Cache.Server, {:refresh})

      assert SecretConfig.fetch!("shared_key_1") == "override_key_1"
      assert SecretConfig.fetch!("shared_key_2") == "override_key_2"
      assert SecretConfig.fetch!("shared_key_3") == "base_key_3"
      assert SecretConfig.fetch!("shared_key_4") == "global_key_4"
      assert SecretConfig.fetch!("shared_key_5") == "global_key_5"
      assert SecretConfig.fetch!("shared_key_6") == "global_key_6"
    end
  end
end

