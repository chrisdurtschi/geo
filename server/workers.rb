require 'sidekiq'

Sidekiq.configure_server do |config|
  require 'sidekiq/middleware/server/unique_jobs'
  config.server_middleware do |chain|
    STDOUT.puts "inserting Sidekiq::Middleware::Client::UniqueJobs into Sidekiq server middleware"
    chain.add Sidekiq::Middleware::Server::UniqueJobs
  end
end

Sidekiq.configure_client do |config|
  require 'sidekiq/middleware/client/unique_jobs'
  config.client_middleware do |chain|
    STDOUT.puts "inserting Sidekiq::Middleware::Client::UniqueJobs into Sidekiq client middleware"
    chain.add Sidekiq::Middleware::Client::UniqueJobs
  end
end

Dir['./server/workers/*.rb'].each { |worker| require "./#{worker}" }
