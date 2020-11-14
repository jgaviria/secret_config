defmodule SecretConfig.Cache.Server do
  use GenServer
  require Logger
  require EEx

  def start_link(opts) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  def init(_opts) do
    env = Application.get_env(:secret_config, :env)
    {:ok, init_state(env)}
  end

  def handle_cast({:set_env, env}, {file_or_ssm, _env, map}) do
    {:noreply, {file_or_ssm, env, map}}
  end

  def handle_cast({:refresh}, {_file_or_ssm, env, _map}) do
    {:noreply, init_state(env)}
  end

  def handle_call({:fetch, key, default}, _from, state = {_file_or_ssm, env, map}) do
    {:reply, Map.get(map, full_key(env, key), default), state}
  end

  def handle_call({:key?, key}, _from, state = {_file_or_ssm, env, map}) do
    {:reply, Map.has_key?(map, full_key(env, key)), state}
  end

  def handle_call({:delete, key}, _from, {:ssm, env, _map}) do
    full_key(env, key)
    |> ExAws.SSM.delete_parameter()
    |> ExAws.request!()

    {:reply, key, init_state(env)}
  end

  def handle_call({:delete, key}, _from, {:local, env, map}) do
    {:reply, key, {:local, env, Map.delete(map, full_key(env, key))}}
  end

  def handle_call({:push, key, value}, _from, {:ssm, env, _map}) do
    full_key(env, key)
    |> ExAws.SSM.put_parameter(:secure_string, value, overwrite: true)
    |> ExAws.request!()

    {:reply, key, init_state(env)}
  end

  def handle_call({:push, key, value}, _from, {:local, env, map}) do
    {:reply, key, {:local, env, Map.put(map, full_key(env, key), value)}}
  end

  defp init_state(env) do
    cond do
      yaml_str = Application.get_env(:secret_config, :yaml_str) ->
        {:local, env, yaml_str_to_map(yaml_str)}
      yaml_file = Application.get_env(:secret_config, :yaml_file) ->
        yaml_str = File.read!(yaml_file)
        {:local, env, yaml_str_to_map(yaml_str)}
      true ->
        {:ssm, env, ssm_parameter_map(%{}, nil, true)}
    end
  end

  defp ssm_parameter_map(map, nil, _first_run = false) do
    map
  end

  defp ssm_parameter_map(map, next_token, _first_run) do
    path = Application.get_env(:secret_config, :env) || "/"

    ssm_params =
      ExAws.SSM.get_parameters_by_path(path,
        recursive: true,
        with_decryption: true,
        next_token: next_token
      )
      |> ExAws.request!()

    next_token = ssm_params["NextToken"]

    map =
      Enum.reduce(ssm_params["Parameters"], map, fn m, acc ->
        Map.put(acc, m["Name"], m["Value"])
      end)

    ssm_parameter_map(map, next_token, false)
  end

  defp pathize_map(yaml_map, prefix, path_map) do
    {_prefix, path_map} = Enum.reduce(yaml_map, {prefix, path_map}, &add_to_path_map/2)
    path_map
  end

  defp add_to_path_map({key, inner_map = %{}}, {prefix, path_map}) do
    path_map = pathize_map(inner_map, prefix <> "/" <> key, path_map)
    {prefix, path_map}
  end

  defp add_to_path_map({key, value}, {prefix, path_map}) do
    {prefix, Map.put(path_map, prefix <> "/" <> key, to_string(value))}
  end

  defp full_key(env, key) do
    "#{env}/#{key}"
  end

  defp yaml_str_to_map(yaml_str) do
    bindings = Application.get_env(:secret_config, :yaml_bindings) || []
    EEx.eval_string(yaml_str, bindings)
    |> YamlElixir.read_from_string!()
    |> pathize_map("", %{})
  end

end
