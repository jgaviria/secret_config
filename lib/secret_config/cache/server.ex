defmodule SecretConfig.Cache.Server do
  use GenServer
  require Logger
  require EEx

  @moduledoc """
  A GenServer for handling secret configurations either locally or via SSM parameter store.
  """

  @doc """
  Starts the GenServer with the given options.

  ## Parameters
  - opts: The options for starting the GenServer.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  @doc """
  Initializes the GenServer state.

  ## Parameters
  - env: The environment name, which can be `nil`, causing fallback to the application config or default.
  """
  @spec init(nil | String.t()) :: {:ok, any()}
  def init(env) do
    env = env || Application.get_env(:secret_config, :env)

    if env == nil do
      {:ok, %{}}
    else
      state = Config.Loader.init_state(env)
      {:ok, state}
    end
  end

  # Handles :set_env cast to update the environment of the GenServer state.
  def handle_cast({:set_env, env}, {file_or_ssm, _env, map}) do
    {:noreply, {file_or_ssm, env, map}}
  end

  def handle_cast({:set_env, env}, %{}) do
    {:noreply, Config.Loader.init_state(env)}
  end

  # Handles :refresh cast to update the environment to the latest state
  def handle_cast({:refresh}, {_file_or_ssm, env, _map}) do
    {:noreply, Config.Loader.init_state(env)}
  end

  # Handles synchronous calls for manipulating configuration values locally (both test and dev)
  def handle_call({:push, key, value}, _from, {:local, env, map}) do
    {:reply, {:added, Util.full_key(env, key)},
     {:local, env, Map.put(map, Util.full_key(env, key), value)}}
  end

  def handle_call({:fetch, key, default}, _from, {:local, env, map}) do
    {:reply, Map.get(map, Util.full_key(env, key), default), {:local, env, map}}
  end

  def handle_call({:fetch!, key, _default}, _from, {:local, env, map} = state) do
    case Map.fetch(map, Util.full_key(env, key)) do
      {:ok, value} ->
        {:reply, value, state}

      :error ->
        {:reply, {:not_exist, key}, state}
    end
  end

  def handle_call({:key?, key}, _from, {:local, env, map}) do
    {:reply, Map.has_key?(map, Util.full_key(env, key)), {:local, env, map}}
  end

  def handle_call({:delete, key}, _from, {:local, env, map} = state) do
    if Map.has_key?(map, Util.full_key(env, key)) do
      {:reply, {:deleted, key}, {:local, env, Map.delete(map, Util.full_key(env, key))}}
    else
      {:reply, {:not_exist, key}, state}
    end
  end

  # Handles synchronous calls for manipulating configuration values via SSM parameter store.

  def handle_call({:push, key, value}, _from, {:ssm, env, _map} = state) do
    full_key = Util.full_key(env, key)

    case ExAws.SSM.put_parameter(full_key, :secure_string, value, overwrite: true)
         |> ExAws.request() do
      {:ok, _response} ->
        {:reply, {:added, full_key}, state}

      {:error, msg} ->
        {:reply, {:error, msg}, state}
    end
  end

  def handle_call({:fetch, key, default}, _from, {:ssm, env, map}) do
    {:reply, Map.get(map, key, default), {:ssm, env, map}}
  end

  def handle_call({:fetch!, key, _default}, _from, {:ssm, env, map} = state) do
    case Map.fetch(map, key) do
      {:ok, value} ->
        {:reply, value, state}

      :error ->
        {:reply, {:not_exist, Util.full_key(env, key)}, state}
    end
  end

  def handle_call({:key?, key}, _from, {:ssm, env, map}) do
    {:reply, Map.has_key?(map, key), {:ssm, env, map}}
  end

  def handle_call({:delete, key}, _from, {:ssm, env, _map} = state) do
    full_key = Util.full_key(env, key)

    case ExAws.SSM.get_parameter(full_key, with_decryption: true)
         |> ExAws.request() do
      {:ok, _response} ->
        ExAws.SSM.delete_parameter(full_key)
        |> ExAws.request!()

        {:reply, {:deleted, full_key}, state}

      {:error, _response} ->
        {:reply, {:not_exist, full_key}, state}
    end
  end
end
