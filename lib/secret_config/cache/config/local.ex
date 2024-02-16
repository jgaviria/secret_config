defmodule Config.Local do
  @moduledoc """
  Handles parsing of local YAML configurations, providing functionality to load configurations
  from YAML strings or files, applying environment-specific interpolations and imports.
  """

  @doc """
  Parses a YAML string into a configuration state, applying environment variable interpolation.

  ## Parameters
  - yaml_str: The YAML string to be parsed.
  - env: The environment context used for interpolation.

  ## Returns
  - A tuple containing `:local`, the environment, and the parsed state as a map.
  """
  @spec parse_yaml(String.t(), String.t()) :: {:local, String.t(), map()}
  def parse_yaml(yaml_str, env) do
    state = yaml_str
            |> Util.yaml_str_to_map()
            |> StringInterpolator.interpolate_env()

    {:local, env, state}
  end

  @doc """
  Reads and parses a YAML file into a configuration state, applying local imports
  and environment variable interpolation.

  ## Parameters
  - file: The path to the YAML file to be read and parsed.
  - env: The environment context used for interpolation and imports.

  ## Returns
  - A tuple containing `:local`, the environment, and the parsed state as a map.
  """
  @spec parse_file(String.t(), String.t()) :: {:local, String.t(), map()}
  def parse_file(file, env) do
    state = file
            |> File.read!()
            |> Util.yaml_str_to_map()
            |> Util.apply_local_imports()
            |> StringInterpolator.interpolate_env()

    {:local, env, state}
  end
end