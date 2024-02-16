defmodule Config.Loader do
  @moduledoc """
  Handles loading of configuration based on the environment setting.

  It supports loading configuration from a YAML string, a YAML file, or an SSM parameter store,
  depending on the application's environment settings.
  """

  @doc """
  Initializes the configuration state based on the provided environment.

  ## Parameters
  - env: The environment name as a string or `nil`.

  ## Returns
  - The loaded configuration as a map, or `nil` if the environment is not set.
  """
  @spec init_state(String.t() | nil) :: {:local, String.t(), map()} | nil
  def init_state(env) do
    case env do
      nil -> nil
      _ -> load_config(env)
    end
  end

  @doc """
  Loads configuration based on the environment setting.

  Attempts to load configuration from a YAML string, then from a file, and finally
  falls back to loading from the SSM parameter store if the previous methods are not configured.

  ## Parameters
  - env: The environment name as a string.

  ## Returns
  - The loaded configuration as a map, wrapped in a tuple with `:local` and the environment,
    or directly from the SSM parameter store.
  """
  @spec load_config(String.t()) :: {:local, String.t(), map()} | any()
  def load_config(env) do
    cond do
      yaml_str = Application.get_env(:secret_config, :yaml_str) ->
        Config.Local.parse_yaml(yaml_str, env)

      file = Application.get_env(:secret_config, :file) ->
        yaml_str = File.read!(file)
        local_map = Util.yaml_str_to_map(yaml_str)
                    |> Util.apply_local_imports
                    |> StringInterpolator.interpolate_env()
        {:local, env, local_map}

      true ->
        Config.SSM.load_ssm_config(env)
    end
  end
end
