defmodule StringInterpolatorTest do
  use ExUnit.Case

  describe "interpolate_env/1" do
    test "raises an exception for missing environment variables" do
      map = %{"missing_test" => "missing_test_${env:MISSING_ENV_VAR}"}

      assert_raise RuntimeError, "Missing mandatory environment variable: MISSING_ENV_VAR", fn ->
        StringInterpolator.interpolate_env(map)
      end
    end

    test "interpolate_env/1 interpolates environment variables" do
      map = %{
        "/dev/app_name/mysql/db" => "${env:TEST_DB}_secret_config",
        "/dev/app_name/mysql/host" => "${env:HOST}_secret_config"
      }

      expected_result = %{
        "/dev/app_name/mysql/db" => "interpolated_secret_config",
        "/dev/app_name/mysql/host" => "interpolated_secret_config"
      }

      assert StringInterpolator.interpolate_env(map) == expected_result
    end
  end
end