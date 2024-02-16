defmodule Util do
  @moduledoc """
  Utility functions for processing configuration data, including parsing YAML strings,
  applying local imports, and handling AWS SSM parameters.
  """

  require EEx

  @doc """
  Converts a YAML string into a nested map, applying EEx evaluation with bindings from the application configuration.

  ## Parameters

  - yaml_str: The YAML string to be converted.

  ## Returns

  - A map representing the YAML structure with paths as keys.
  """
  @spec yaml_str_to_map(String.t()) :: map()
  def yaml_str_to_map(yaml_str) do
    bindings = Application.get_env(:secret_config, :yaml_bindings) || []
    yaml_str
    |> EEx.eval_string(bindings)
    |> YamlElixir.read_from_string!()
    |> pathize_map("", %{})
  end

  @doc """
  Recursively constructs a map from YAML data, transforming nested structures into a flattened path map.

  ## Parameters

  - yaml_map: The nested map obtained from YAML parsing.
  - prefix: The current path prefix, used for recursion.
  - path_map: The accumulator for the flattened path map.

  ## Returns

  - A flattened path map representing the YAML structure.
  """
  @spec pathize_map(map(), String.t(), map()) :: map()
  def pathize_map(yaml_map, prefix, path_map) do
    {_prefix, path_map} = Enum.reduce(yaml_map, {prefix, path_map}, &add_to_path_map/2)
    path_map
  end

  # Private helper functions for internal use within the module
  defp add_to_path_map({key, inner_map = %{}}, {prefix, path_map}) do
    path_map = pathize_map(inner_map, prefix <> "/" <> key, path_map)
    {prefix, path_map}
  end

  defp add_to_path_map({key, value}, {prefix, path_map}) do
    {prefix, Map.put(path_map, prefix <> "/" <> key, to_string(value))}
  end

  @doc """
  Applies local import rules to a configuration map, handling special keys for import directives.

  ## Parameters

  - map: The initial configuration map.

  ## Returns

  - A modified map with local imports applied.
  """
  @spec apply_local_imports(map()) :: map()
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

  @doc false
  def fetch_local_imports(map, import_key, parent_key) do
    reduced_map =
      Enum.reduce(
        map,
        %{},
        fn {key, value}, acc ->
          if Regex.match?(~r/#{import_key}/, key) do
            str = String.split(key, import_key, trim: true)
            modified_key = String.replace(parent_key, "__import__", "#{str}")
            Map.put(acc, modified_key, value)
          else
            acc
          end
        end
      )

    reduced_map
  end

  @doc """
  Applies imports from SSM parameters into the initial configuration map.

  ## Parameters

  - init_map: The initial configuration map before imports.
  - app_prefix: A prefix used to scope the SSM parameter imports.

  ## Returns

  - A configuration map with SSM imports applied.
  """
  @spec apply_imports(map(), String.t()) :: map()
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

  @spec ssm_parameter_map(map(), nil | String.t(), boolean(), String.t()) :: map()
  def ssm_parameter_map(map, nil, _first_run = false, _path) do
    map
  end

  def ssm_parameter_map(map, next_token, _first_run, path) do
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

  @doc """
  Constructs a full key by combining the environment prefix and the specific key.

  ## Parameters

  - env: The environment name or prefix.
  - key: The specific configuration key.

  ## Returns

  - A string representing the full key path.
  """
  @spec full_key(String.t(), String.t()) :: String.t()
  def full_key(env, key) do
    "#{env}/#{key}"
  end

end