defmodule Config.SSM do
  @moduledoc """
  Provides functionality to load configuration settings from AWS SSM Parameter Store
  based on the provided environment.
  """

  @doc """
  Loads configuration from the AWS SSM Parameter Store for the specified environment.

  Utilizes utility functions to fetch parameters, apply imports, and interpolate
  environment variables within the parameters.

  ## Parameters
  - env: The environment name as a string which scopes the SSM parameter lookup.

  ## Returns
  - A tuple with `:ssm`, the environment name, and the configuration map.
  """
  @spec load_ssm_config(String.t()) :: {:ssm, String.t(), map()}
  def load_ssm_config(env) do
    ssm_map = Util.ssm_parameter_map(%{}, nil, true, env)
              |> Util.apply_imports(env)
              |> StringInterpolator.interpolate_env()

    {:ssm, env, ssm_map}
  end
end
