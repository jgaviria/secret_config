System.put_env("TEST_DB", "interpolated")
System.put_env("HOST", "interpolated")

ExUnit.start(exclude: [:ssm_test])
