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
  @spec set_env(env :: binary) :: none()
  def set_env(env) do
    GenServer.cast(SecretConfig.Cache.Server, {:set_env, env})
  end

  @doc """
  Gets parameter from GenServer (returns default value if present)
  """
  @spec fetch(key :: binary, default :: binary | nil) :: ExAws.Operation.JSON.t()
  def fetch(key, default \\ nil) do
    GenServer.call(SecretConfig.Cache.Server, {:fetch, key, default})
  end

  @doc """
  Gets parameter from GenServer (raise error if the value is not present)
  """
  @spec fetch!(key :: binary) :: ExAws.Operation.JSON.t()
  def fetch!(key) do
    case GenServer.call(SecretConfig.Cache.Server, {:fetch, key, :not_exist}) do
      :not_exist -> raise "SecretConfig key does not exist: #{inspect(key)}"
      val -> val
    end
  end

  @doc """
  Checks for parameter to be present
  """
  @spec key?(key :: binary) :: ExAws.Operation.JSON.t()
  def key?(key) do
    GenServer.call(SecretConfig.Cache.Server, {:key?, key})
  end

  @doc """
  Deletes parameter from the AWS Parameter Store, then it triggers a refresh of the GenServer state
  """
  @spec delete(key :: binary) :: ExAws.Operation.JSON.t()
  def delete(key) do
    GenServer.call(SecretConfig.Cache.Server, {:delete, key})
  end

  @doc """
  Adds parameter to the AWS Parameter Store, then it triggers a refresh of the GenServer state
  """

  @spec push(key :: binary, value :: binary) :: ExAws.Operation.JSON.t()
  def push(key, value) do
    GenServer.call(SecretConfig.Cache.Server, {:push, key, value})
  end

  @doc """
  Triggers a refresh of the GenServer state by pulling the latest from the AWS Parameter Store
  """
  @spec refresh() :: none()
  def refresh() do
    GenServer.cast(SecretConfig.Cache.Server, {:refresh})
  end

  @doc """
  Convert a yaml to a map.  Useful in a config file for applications that use Docker
  since your local file may no longer be there.
  """
  @spec file_to_map(String.t()) :: map()
  def file_to_map(file) do
    if String.ends_with?(file, ".eex") do
      bindings = Application.get_env(:secret_config, :file_bindings) || []

      EEx.eval_file(file, bindings)
      |> YamlElixir.read_from_string!()
    else
      YamlElixir.read_from_file!(file)
    end
  end
end
