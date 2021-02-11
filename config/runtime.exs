import Config
stack =
  case config_env() do
    :prod -> System.fetch_env!("STACK_NAME")
    env -> env
  end

Application.ensure_all_started(:secret_config)
# We can't configure :env inside this file and also call ensure_all_started on secret_config
# so make an explicit call.
SecretConfig.set_env("/#{stack}/app_name")

