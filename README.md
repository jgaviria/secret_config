# SecretConfig

**TODO: Add description**

## Installation

Upon starting the umbrella app, SecretConfig will read all the parameters under the configured path and will load them into memory. 

Usage:

```elixir
  SecretConfig.push(key, value)
  SecretConfig.fetch(key)
  SecretConfig.delete(key)
  SecretConfig.refresh()
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/secret_config](https://hexdocs.pm/secret_config).
