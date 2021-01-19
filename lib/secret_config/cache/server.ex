defmodule SecretConfig.Cache.Server do
  use GenServer
  require Logger
  require EEx

  def start_link(opts) do
    GenServer.start_link(__MODULE__, nil, opts)
  end

  def init(_opts) do
    {:ok, init_state()}
  end

  def handle_cast({:refresh}, _state) do
    {:noreply, init_state()}
  end

  def handle_call({:fetch, key, default}, _from, state = {_file_or_ssm, map}) do
    {:reply, Map.get(map, key, default), state}
  end

  def handle_call({:key?, key}, _from, state = {_file_or_ssm, map}) do
    {:reply, Map.has_key?(map, key), state}
  end

  def handle_call({:delete, key}, _from, {:ssm, _map}) do
    ExAws.SSM.delete_parameter(key)
    |> ExAws.request!()

    {:reply, key, init_state()}
  end

  def handle_call({:delete, key}, _from, {:file, map}) do
    {:reply, key, {:file, Map.delete(map, key)}}
  end

  def handle_call({:push, key, value}, _from, {:ssm, _map}) do
    ExAws.SSM.put_parameter(key, :secure_string, value, overwrite: true)
    |> ExAws.request!()

    {:reply, key, init_state()}
  end

  def handle_call({:push, key, value}, _from, {:file, map}) do
    {:reply, key, {:file, Map.put(map, key, value)}}
  end

  defp init_state() do
    if local_ssm_file = Application.get_env(:secret_config, :file) do
      {:file, local_ssm_map(local_ssm_file)}
    else
      ssm_map = ssm_parameter_map(%{}, nil, true, Application.get_env(:secret_config, :env))
                |> apply_imports

      {:ssm, ssm_map}
    end
  end

  def apply_imports(map) do
    reduced_map =
      Enum.reduce(
        map,
        %{},
        fn {key, value}, acc ->
          if Regex.match?(~r/__import__/, key) do
            init_map = Map.delete(map, key)
            imports_map = ssm_parameter_map(acc, nil, true, value)
            Map.merge(init_map, imports_map, fn _k, v1, _v2 -> v1 end)
          else
            Map.put(acc, key, value)
          end
        end
      )

    if Map.has_key?(reduced_map, "/__import__") do
      apply_imports(reduced_map)
    else
      reduced_map
    end
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
          stripped_key = String.split(key, path, trim: true)
                        |> Enum.at(0)
          Map.put(acc, stripped_key, value)
        end
      )

    ssm_parameter_map(map, next_token, false, path)
  end

  defp local_ssm_map(local_ssm_file) do
    if String.ends_with?(local_ssm_file, ".eex") do
      bindings = Application.get_env(:secret_config, :file_bindings) || []

      EEx.eval_file(local_ssm_file, bindings)
      |> YamlElixir.read_from_string!()
    else
      YamlElixir.read_from_file!(local_ssm_file)
    end
    |> pathize_map("", %{})
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
end
