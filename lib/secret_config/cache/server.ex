defmodule SecretConfig.Cache.Server do
  use GenServer
  require Logger
  require EEx

  def start_link(opts) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  def init(_opts) do
    env = Application.get_env(:secret_config, :env)
    if env == nil do
      {:ok, %{}}
    else
      {:ok, init_state(env)}
    end
  end

  def handle_cast({:set_env, env}, {file_or_ssm, _env, map}) do
    {:noreply, {file_or_ssm, env, map}}
  end

  def handle_cast({:set_env, env}, %{}) do
    {:noreply, init_state(env)}
  end

  def handle_cast({:refresh}, {_file_or_ssm, env, _map}) do
    {:noreply, init_state(env)}
  end

  # Handle calls from the local config
  def handle_call({:push, key, value}, _from, {:local, env, map}) do
    {:reply, key, {:local, env, Map.put(map, full_key(env, key), value)}}
  end

  def handle_call({:fetch, key, default}, _from, {:local, env, map}) do
    {:reply, Map.get(map, full_key(env, key), default), {:local, env, map}}
  end

  def handle_call({:key?, key}, _from, {:local, env, map}) do
    {:reply, Map.has_key?(map, full_key(env, key)), {:local, env, map}}
  end

  def handle_call({:delete, key}, _from, {:local, env, map}) do
    {:reply, key, {:local, env, Map.delete(map, key)}}
  end


  # Handle calls for SSM parameter store
  def handle_call({:push, key, value}, _from, {:ssm, env, map}) do
    full_key(env, key)
    |> ExAws.SSM.put_parameter(:secure_string, value, overwrite: true)
    |> ExAws.request!()

    {:reply, key, {:ssm, env, Map.put(map, full_key(env, key), value)}}
  end

  def handle_call({:fetch, key, default}, _from, {:ssm, env, map}) do
    {:reply, Map.get(map, key, default), {:ssm, env, map}}
  end

  def handle_call({:key?, key}, _from, {:ssm, env, map}) do
    {:reply, Map.has_key?(map, key), {:ssm, env, map}}
  end

  def handle_call({:delete, key}, _from, {:ssm, env, map}) do
    full_key(env, key)
    |> ExAws.SSM.delete_parameter()
    |> ExAws.request!()

    {:reply, key, {:ssm, env, Map.delete(map, full_key(env, key))}}
  end

  defp init_state(env) do
    cond do
      yaml_str = Application.get_env(:secret_config, :yaml_str) ->
        {:local, env, yaml_str_to_map(yaml_str)}
      file = Application.get_env(:secret_config, :file) ->
        yaml_str = File.read!(file)
        local_map = yaml_str_to_map(yaml_str)
                    |> apply_local_imports

        {:local, env, local_map}
      true ->
        ssm_map = ssm_parameter_map(%{}, nil, true, env)
                  |> apply_imports(env)

        {:ssm, env, ssm_map}
    end
  end

  def apply_local_imports(map) do
    reduced_map =
      Enum.reduce(
        map,
        %{},
        fn {key, value}, acc ->
          if Regex.match?(~r/__import__/, key) do
            init_map = Map.delete(map, key)
            imports_map = fetch_local_imports(init_map, value, key)
            map = Map.merge(init_map, imports_map, fn _k, v1, _v2 -> v1 end)
            apply_local_imports(map)
          else
            Map.put(acc, key, value)
          end
        end
      )

    reduced_map
  end

  def fetch_local_imports(map, import_key, parent_key) do
    import_prefix = String.split(import_key, "/", trim: true)
                    |> Enum.at(1)
    parent_prefix = String.split(parent_key, "/", trim: true)
                    |> Enum.at(1)

    reduced_map =
      Enum.reduce(
        map,
        %{},
        fn {key, value}, acc ->
          if Regex.match?(~r/#{import_key}/, key) do
            str = String.split(key, "/#{import_prefix}", trim: true)
            [_head | tail] = str
            pathize_key = Enum.join(tail, "/")
            modified_key = "/#{Mix.env}/#{parent_prefix}#{pathize_key}"
            Map.put(acc, modified_key, value)
          else
            acc
          end
        end
      )

    reduced_map
  end

  def apply_imports(init_map, app_prefix) do
    reduced_map =
      Enum.reduce(
        init_map,
        %{},
        fn {key, path}, acc ->
          if Regex.match?(~r/__import__/, key) do
            init_map = Map.delete(acc, key)
            prefixed_key = String.replace(key, ["__import__", "/"], "")

            imports_map =
              Enum.reduce(
                ssm_parameter_map(%{}, nil, true, path),
                %{},
                fn {key, value}, acc ->
                  if prefixed_key == "" do
                    Map.put(acc, key, value)
                  else
                    key = "#{prefixed_key}/#{key}"
                    Map.put(acc, key, value)
                  end
                end
              )

            map = Map.merge(init_map, imports_map, fn _k, v1, _v2 -> v1 end)
            apply_imports(map, app_prefix)
          else
            Map.put(acc, key, path)
          end
        end
      )

    reduced_map
  end

  defp ssm_parameter_map(map, nil, _first_run = false, _path) do
    map
  end

  defp ssm_parameter_map(map, next_token, _first_run, path) do
    ssm_params =
      ExAws.SSM.get_parameters_by_path(
        path,
        recursive: true,
        with_decryption: true,
        next_token: next_token
      )
      |> ExAws.request!()

    next_token = ssm_params["NextToken"]

    map =
      Enum.reduce(
        ssm_params["Parameters"],
        map,
        fn m, acc ->
          key = m["Name"]
          value = m["Value"]
          prefixed_key = String.replace(key, "#{path}/", "")
          Map.put(acc, prefixed_key, value)
        end
      )

    ssm_parameter_map(map, next_token, false, path)
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
