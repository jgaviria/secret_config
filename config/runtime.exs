import Config
Application.ensure_all_started(:secret_config)
# We can't configure :env inside this file and also call ensure_all_started on secret_config
# so make an explicit call.
SecretConfig.set_env("/#{config_env()}/app_name")

