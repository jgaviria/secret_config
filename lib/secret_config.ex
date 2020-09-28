defmodule SecretConfig do
  @moduledoc """
  Handles CRUD operations to interact with AWS SSM Parameter Store.
  parameters are pushed to SSM as secure strings (encrypted) but then
  added as plain text into the GenServer's internal state
  """

  @doc """
  Gets parameter from GenServer (returns default value if present)
  """
  @spec fetch(key :: default :: binary) :: ExAws.Operation.JSON.t()
  def fetch(key, default \\ []) do
    key = "#{Application.get_env(:secret_config, :env)}/#{key}"
    GenServer.call(SecretConfig.Cache.Server, {:fetch, key, default})
  end

  @doc """
  Checks for parameter to be present
  """
  @spec key?(key :: default :: binary) :: ExAws.Operation.JSON.t()
  def key?(key, default \\ []) do
    key = "#{Application.get_env(:secret_config, :env)}/#{key}"
    GenServer.call(SecretConfig.Cache.Server, {:key?, key})
  end

  @doc """
  Deletes parameter from the AWS Parameter Store, then it triggers a refresh of the GenServer state
  """

  @spec delete(key :: binary) :: ExAws.Operation.JSON.t()
  def delete(key) do
    key = "#{Application.get_env(:secret_config, :env)}/#{key}"
    GenServer.call(SecretConfig.Cache.Server, {:delete, key})
  end

  @doc """
  Adds parameter to the AWS Parameter Store, then it triggers a refresh of the GenServer state
  """

  @spec push(key :: binary, value :: binary) :: ExAws.Operation.JSON.t()
  def push(key, value) do
    key = "#{Application.get_env(:secret_config, :env)}/#{key}"
    GenServer.call(SecretConfig.Cache.Server, {:push, key, value})
  end

  @doc """
  Triggers a refresh of the GenServer state by pulling the latest from the AWS Parameter Store
  """

  def refresh() do
    GenServer.cast(SecretConfig.Cache.Server, {:refresh})
  end
end

