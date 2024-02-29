defmodule SecretConfig do
  @moduledoc """
  Handles CRUD operations to interact with AWS SSM Parameter Store.
  parameters are pushed to SSM as secure strings (encrypted) but then
  added as plain text into the GenServer's internal state
  """

  @doc """
  Sets the env explicitly as this configuration item may not be able to be set
  inside a releases.exs or runtime.exs if you perform ensure_all_started(:secret_config)
  """
  @spec set_env(env :: binary) :: :ok
  def set_env(env) do
    GenServer.cast(SecretConfig.Cache.Server, {:set_env, env})
  end

  @doc """
  Gets parameter from GenServer (returns default value if present)
  """
  @spec fetch(key :: binary, default :: binary | nil) :: binary | nil
  def fetch(key, default) do
    GenServer.call(SecretConfig.Cache.Server, {:fetch, key, default})
  end

  @doc """
  Gets parameter from GenServer (raise error if the value is not present)
  """
  @spec fetch!(key :: String.t()) :: String.t()
  def fetch!(key) do
    case GenServer.call(SecretConfig.Cache.Server, {:fetch!, key, :not_exist}) do
      {:not_exist, full_key} ->
        raise "SecretConfig key does not exist: #{inspect(full_key)}"

      value ->
        value
    end
  end

  @doc """
  Checks for parameter to be present
  """
  @spec key?(key :: binary) :: boolean()
  def key?(key) do
    GenServer.call(SecretConfig.Cache.Server, {:key?, key})
  end

  @doc """
  Deletes parameter from the AWS Parameter Store, then it triggers a refresh of the GenServer state
  """
  @spec delete(key :: binary) :: {:deleted, binary} | {:not_exist, binary}
  def delete(key) do
    GenServer.call(SecretConfig.Cache.Server, {:delete, key})
  end

  @doc """
  Adds parameter to the AWS Parameter Store, then it triggers a refresh of the GenServer state
  """

  @spec push(key :: binary, value :: binary) :: {:added, binary} | {:error, binary}
  def push(key, value) do
    GenServer.call(SecretConfig.Cache.Server, {:push, key, value})
  end

  @doc """
  Triggers a refresh of the GenServer state by pulling the latest from the AWS Parameter Store
  """
  @spec refresh() :: :ok
  def refresh() do
    GenServer.cast(SecretConfig.Cache.Server, {:refresh})
  end
end
