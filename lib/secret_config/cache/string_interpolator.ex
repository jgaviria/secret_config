defmodule StringInterpolator do
  @moduledoc """
  Provides functionality for interpolating environment variables into strings within a map.
  """

  @doc """
  Interpolates environment variables into the values of a given map.

  Iterates over each key-value pair in the map, replacing placeholders in the values
  with the corresponding environment variable values. If an environment variable is missing,
  a RuntimeError is raised indicating the missing variable.

  ## Parameters

  - map: A map with string values possibly containing placeholders for environment variables
    in the format `${env:VAR_NAME}`.

  ## Returns

  - A new map with the same keys but with interpolated values.

  ## Examples

      iex> StringInterpolator.interpolate_env(%{"greeting" => "Hello, ${env:USER}"})
      %{"greeting" => "Hello, Alice"}

  ## Errors

  - Raises `RuntimeError` if an environment variable referenced in a value does not exist.

  """
  @spec interpolate_env(map :: map()) :: map()
  def interpolate_env(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      interpolated_value = interpolate_string(value)
      Map.put(acc, key, interpolated_value)
    end)
  end

  @doc false
  @spec interpolate_string(value :: binary()) :: binary()
  defp interpolate_string(value) when is_binary(value) do
    Regex.replace(~r/\$\{env:([^\}]+)\}/, value, fn _match, env_var_name ->
      case System.get_env(env_var_name) do
        nil -> raise("Missing mandatory environment variable: #{env_var_name}")
        env_value -> env_value
      end
    end)
  end

  @doc false
  @spec interpolate_string(value :: any()) :: any()
  defp interpolate_string(value), do: value
end
