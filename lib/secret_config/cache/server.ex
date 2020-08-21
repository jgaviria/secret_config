defmodule SecretConfig.Cache.Server do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(opts) do
    GenServer.cast(SecretConfig.Cache.Server, {:refresh})
    {:ok, opts}
  end

  def handle_cast({:refresh}, _map) do
    {:noreply, ssm_parameter_map()}
  end

  def handle_call({:fetch, key, default}, _from, state) do
    if Enum.member?([:dev], Mix.env) do
      {:reply, local_ssm_map(key), state}
    else
      {:reply, Map.get(state, key, default), state}
    end
  end

  def handle_call({:delete, key}, _from, state) do
    IO.inspect ExAws.SSM.delete_parameter(key)
    |> ExAws.request!()

    {:reply, key, ssm_parameter_map()}
  end

  def handle_call({:push, key, value}, _from, state) do
    ExAws.SSM.put_parameter(key, :secure_string, value, overwrite: true)
    |> ExAws.request!()

    {:reply, key, ssm_parameter_map()}
  end

  defp ssm_parameter_map() do
    ssm_params = ExAws.SSM.get_parameters_by_path("/", recursive: true, with_decryption: true)
                 |> ExAws.request!()

    map = Enum.reduce ssm_params["Parameters"], %{}, fn (map, acc) ->
      Map.put(acc, map["Name"], map["Value"])
    end
    map
  end

  defp local_ssm_map(path) do
    env = Mix.env()
          |> Atom.to_string()
    local_ssm = Path.join(File.cwd!(), "lib/fixtures/ssm_parameters.yml")

    with {:ok, parameters} <- YamlElixir.read_from_file(local_ssm) do
      key = String.split(path, "/", trim: true)
      get_in(parameters, key)
    end
  end
end
