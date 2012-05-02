require 'sidekiq'

Sidekiq.configure_client do |config|
  config.redis = { size: 1, namespace: "geo" }
end

require 'sidekiq/web'
run Sidekiq::Web
