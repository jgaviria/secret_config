import Config

config :secret_config,
  env: "/#{Mix.env}/app_name",
  yaml_file: __DIR__ <> "/secret_config.yml"
