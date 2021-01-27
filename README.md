# SecretConfig

Upon starting your app SecretConfig will read all the parameters under the configured path and will load them into memory. The reasoning behind this is to limit the amount of API calls to the ssm parameter store but rather doing them against a local GenServer. Actions like push or delete will first update aws ssm and then immediately update the GenServer state. 

## Status
Early prototype code, not for production use.

## Installation

Add to your list of depencies in `mix.exs`:

~~~elixir
def deps do
  [
    {:secret_config, "~> 0.11.0"}
  ]
end
~~~
## Configuration
You can set service specific configuration for both `ex_aws_ssm` and `ex_aws` (otherwise it defaults to `us-east-1`)

```elixir
config :ex_aws, ssm: [
  region: "us-west-2"
]
```

ExAws requires valid AWS keys in order to work properly. ExAws by default does the equivalent of:

```elixir
config :ex_aws,
  access_key_id: [{:system, "AWS_ACCESS_KEY_ID"}, :instance_role],
  secret_access_key: [{:system, "AWS_SECRET_ACCESS_KEY"}, :instance_role]
```
The above means it will try to resolve credentials in order:

1. It kooks for the AWS standard AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables

2. Resolves credentials with IAM, if running inside ECS and a task role has been assigned it will use it
Otherwise it will fall back to the instance role

See https://github.com/ex-aws/ex_aws and https://github.com/hellogustav/ex_aws_ssm for detailed config docs. 

Prepend your env and app_name:
```elixir
config :secret_config, env: "/#{Mix.env}/app_name"
```

Set up the path to the local yml file (for test and dev)
```elixir
config :secret_config, file: __DIR__ <> "/secret_config.yml"
```

If using Docker, you may want to avoid local files so you can use yaml_str instead of file
```elixir
config :secret_config, yaml_str: File.read!(__DIR__ <> "/secret_config.yml")
```

SecretConfig supports dev and test environments. It will bypass the aws ssm call and read from a yaml file. It is important this file is created as follows `/secret_config.yml`. Also the env/app_name must match the above config (env/app_name):
```elixir
dev:
  app_name:
    customer_1:
      pgp_key: test_key

test:
  app_name:
    customer_2:
      pgp_key: test_key
```


## Usage:

Pushes to the parameter store, then triggers a refresh of the in-memory state (`no leading /`):
```elixir
  SecretConfig.push("path/key_name/name", "value")
```
Fetches from the local in-memory state. If you provide a default and the key is not found, it will return its default value:
```elixir
  SecretConfig.fetch("path/key_name/name", "default")
```
Fetches from the local in-memory state. Raises a runtime error if the key doesn't exist:
```elixir
  SecretConfig.fetch!("path/key_name/non_existing_name")
```
Deletes from ssm parameter store and then triggers a refresh of the in-memory state
```elixir
  SecretConfig.delete("path/key_name/name")
```
Triggers a refresh of the in-memory state by pulling the latest from the AWS Parameter Store
```elixir
  SecretConfig.refresh()
```
##Run Integration test against the AWS Parameter Store:


This runs the integration test which are skipped by default. You must have AWS creds already loaded in the console where the test will be running:
```elixir
export AWS_ACCESS_KEY_ID="key"
export AWS_SECRET_ACCESS_KEY="key"
export BUCKET_NAME=bucket-name
```
```elixir
  mix test --only ssm_test --seed 0
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/secret_config](https://hexdocs.pm/secret_config).
