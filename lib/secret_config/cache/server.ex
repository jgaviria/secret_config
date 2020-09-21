defmodule SecretConfig.Cache.Server do
  use GenServer
  require Logger

  # Don't use Mix.env in runtime code
  @mix_env Mix.env()

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(opts) do
    if Enum.member?([:dev], @mix_env) do
      {}
    else
      GenServer.cast(SecretConfig.Cache.Server, {:refresh})
    end
    {:ok, opts}
  end

  def handle_cast({:refresh}, _map) do
    {:noreply, ssm_parameter_map()}
  end

  def handle_call({:fetch, key, default}, _from, state) do
    if Enum.member?([:dev], @mix_env) do
      {:reply, local_ssm_map(key), state}
    else
      {:reply, Map.get(state, key, default), state}
    end
  end

  def handle_call({:delete, key}, _from, _state) do
    IO.inspect ExAws.SSM.delete_parameter(key)
    |> ExAws.request!()

    {:reply, key, ssm_parameter_map()}
  end

  def handle_call({:push, key, value}, _from, _state) do
    ExAws.SSM.put_parameter(key, :secure_string, value, overwrite: true)
    |> ExAws.request!()

    {:reply, key, ssm_parameter_map()}
  end

  defp ssm_parameter_map() do
    path = Application.get_env(:secret_config, :env) || "/"
    ssm_params = ExAws.SSM.get_parameters_by_path(path, recursive: true, with_decryption: true) |> ExAws.request!()

    map = Enum.reduce ssm_params["Parameters"], %{}, fn (map, acc) ->
      Map.put(acc, map["Name"], map["Value"])
    end
    map
  end

  defp local_ssm_map(path) do
    local_ssm = Path.join(File.cwd!(), "lib/fixtures/ssm_parameters.yml")

    with {:ok, parameters} <- YamlElixir.read_from_file(local_ssm) do
      key = String.split(path, "/", trim: true)
      get_in(parameters, key)
    end
  end
end
