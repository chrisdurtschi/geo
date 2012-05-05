require 'yajl/http_stream'

require File.join(File.dirname(__FILE__), 'config')
require File.join(File.dirname(__FILE__), 'workers')

$stdout.sync = true

seq = 0

while true
  url = "#{Geo::Config.url}/_changes?feed=continuous&heartbeat=2000&filter=app/new_images&since=#{seq}"
  STDOUT.puts "Starting to listen to URL #{url}"

  Yajl::HttpStream.get(url, symbolize_keys: true) do |change|
    STDOUT.puts "Got a _changes update: #{change}"

    if change && change[:id] && !change[:deleted]
      ImageVersionWorker.perform_async change[:id]
      seq = change[:seq]
    end
  end
  STDOUT.puts "_changes feed died, restarting at sequence #{seq}"
end
