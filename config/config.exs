import Config

config :secret_config, env: "/#{Mix.env}/app_name"
config :secret_config, file: __DIR__ <> "/secret_config.yml"
