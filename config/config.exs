# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

config :rabbitci_core, :app_namespace, RabbitCICore

# Configures the endpoint
config :rabbitci_core, RabbitCICore.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "MOd1xikwYz0y3kr5GlBxA4pDUf5catrgRfANogH5PaCp4QcaJXKpnvorZLq6j6DH",
  debug_errors: false,
  root: Path.expand("..", __DIR__),
  pubsub: [name: RabbitCICore.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $levelpad$message\n",
  metadata: [:request_id]

config :plug, :mimes, %{
  "application/vnd.api+json" => ["json"]
}

config :build_man, :worker_limit, 2
config :build_man, :config_extraction_limit, 2
config :build_man, :log_streamer_limit, 10

config :build_man, :build_logs_exchange, "rabbitci.build_logs"
config :build_man, :build_logs_queue, "rabbitci.build_logs"
config :build_man, :build_exchange, "rabbitci.builds"
config :build_man, :build_queue, "rabbitci.builds"
config :build_man, :config_extraction_exchange, "rabbitci.config_extraction"
config :build_man, :config_extraction_queue, "rabbitci.config_extraction"

import_config "#{Mix.env}.exs"
