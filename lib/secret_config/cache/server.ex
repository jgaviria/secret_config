defmodule SecretConfig.Cache.Server do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(opts) do
    if Enum.member?([:test, :dev], Application.get_env(:secret_config, :mix_env)) do
      {}
    else
      GenServer.cast(SecretConfig.Cache.Server, {:refresh})
    end
    {:ok, opts}
  end

  def handle_cast({:refresh}, _map) do
    {:noreply, ssm_parameter_map(%{}, nil, true)}
  end

  def handle_call({:fetch, key, default}, _from, state) do
    if Enum.member?([:test, :dev], Application.get_env(:secret_config, :mix_env)) do
      {:reply, local_ssm_map(key), state}
    else
      {:reply, Map.get(state, key, default), state}
    end
  end

  def handle_call({:key?, key}, _from, state) do
    {:reply, Map.has_key?(state, key), state}
  end

  def handle_call({:delete, key}, _from, _state) do
    ExAws.SSM.delete_parameter(key)
    |> ExAws.request!()

    {:reply, key, ssm_parameter_map(%{}, nil, true)}
  end

  def handle_call({:push, key, value}, _from, _state) do
    ExAws.SSM.put_parameter(key, :secure_string, value, overwrite: true)
    |> ExAws.request!()

    {:reply, key, ssm_parameter_map(%{}, nil, true)}
  end

  defp ssm_parameter_map(map, nil, _first_run = false) do
    map
  end

  defp ssm_parameter_map(map, next_token, _first_run) do
    path = Application.get_env(:secret_config, :env) || "/"
    ssm_params = ExAws.SSM.get_parameters_by_path(path, recursive: true, with_decryption: true, next_token: next_token) |> ExAws.request!()
    next_token = ssm_params["NextToken"]

    map = Enum.reduce ssm_params["Parameters"], map, fn (m, acc) ->
      Map.put(acc, m["Name"], m["Value"])
    end

    ssm_parameter_map(map, next_token, false)
  end

  defp local_ssm_map(path) do
    local_ssm = Application.get_env(:secret_config, :file)

    with {:ok, parameters} <- YamlElixir.read_from_file(local_ssm) do
      key = String.split(path, "/", trim: true)
      get_in(parameters, key)
    end
  end
end
