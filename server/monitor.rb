require 'yajl/http_stream'

require File.join(File.dirname(__FILE__), 'config')
require File.join(File.dirname(__FILE__), 'workers')

url = "#{Geo::Config.url}/_changes?feed=continuous&heartbeat=30000&filter=app/new_tags"
STDOUT.puts "Starting to listen to #{url}"

Yajl::HttpStream.get(url, :symbolize_keys => true) do |change|
  if change && change[:id] && !change[:deleted]
    STDOUT.puts "Got a _changes update: #{change.inspect}"
    TagVersionWorker.perform_async change[:id]
  end
end
