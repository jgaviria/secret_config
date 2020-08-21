# SecretConfig

Upon starting your app SecretConfig will read all the parameters under the configured path and will load them into memory. The reasoning behind this is to limit the amount of API calls to the ssm parameter store but rather doing them against a local GenServer. Every action (push, delete, refresh) will first update aws ssm and then immediately the GenServer state. 

## Status
Early prototype code, not for production use.

## Installation

Add to your list of depencies in `mix.exs`:

~~~elixir
def deps do
  [
    {:secret_config, "~> 0.1"}
  ]
end
~~~
## Configuration
You can set service specific configuration for both `ssm` and `ex_aws` (otherwise it defaults to `us-east-1`)

```elixir
config :ex_aws, ssm: [
  region: "us-west-2"
]
```

Prepend your env and app_name:
```elixir
config :secret_config, env: "/#{Mix.env}/app_name"
```

SecretConfig supports dev and test environments. It will bypass the aws ssm call and read from a yaml file. It is important this file is created as follows `lib/fixtures/ssm_parameters.yml`. Also the env/app_name must match the above config (env/app_name)
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


##Usage:

Push a parameter to ssm parameter store, then triggers a refresh of the in-memory state:
```elixir
  SecretConfig.push(key, value)
```
Fetch from the local in-memory state. If you provide a default and the key is not found, it will return it:
```elixir
  SecretConfig.fetch(key, default)
```
Deletes from ssm parameter store and then triggers a refresh of the in-memory state
```elixir
  SecretConfig.delete(key)
```
Triggers a refresh of the in-memory state by pulling the latest from the AWS Parameter Store
```elixir
  SecretConfig.refresh()
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/secret_config](https://hexdocs.pm/secret_config).
