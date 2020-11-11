defmodule SecretConfig.MixProject do
  use Mix.Project

  def project do
    [
      app: :secret_config,
      version: "0.12.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      package: package(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {SecretConfig.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0"},
      {:ex_aws_ssm, "~> 2.0"},
      {:httpoison, ">= 0.0.0"},
      {:jason, "~> 1.0"},
      {:yaml_elixir, "~> 2.5"},
      {:configparser_ex, "~> 4.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      description:
        "SSM client which handles CRUD operations to interact with AWS SSM Parameter Store",
      maintainers: ["Juan Gaviria"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/jgaviria/secret_config"}
    ]
  end

end
