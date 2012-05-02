require 'yajl'
require 'em-http'

require File.join(File.dirname(__FILE__), 'config')
require File.join(File.dirname(__FILE__), 'workers')

$stdout.sync = true

EM.run {
  capture_url = "#{Geo::Config.url}/_changes?feed=continuous&heartbeat=2000&filter=app/new_captures"
  STDOUT.puts "Starting to listen to capture URL #{capture_url}"

  capture = EM::HttpRequest.new(capture_url).get inactivity_timeout: 0
  capture.stream do |chunk|
    next if chunk.strip == ""

    STDOUT.puts "Got a _changes update for capture: #{chunk}"
    change = Yajl::Parser.parse chunk

    if change && change['id'] && !change['deleted']
      CaptureVerifyWorker.perform_async change['id']
    end
  end
  capture.errback do
    STDOUT.puts "capture _changes feed died"
    EM.stop
  end


  tag_url = "#{Geo::Config.url}/_changes?feed=continuous&heartbeat=2000&filter=app/new_tags"
  STDOUT.puts "Starting to listen to tag URL #{tag_url}"

  tag = EM::HttpRequest.new(tag_url).get inactivity_timeout: 0
  tag.stream do |chunk|
    next if chunk.strip == ""

    STDOUT.puts "Got a _changes update for tag: #{chunk}"
    change = Yajl::Parser.parse chunk

    if change && change['id'] && !change['deleted']
      TagVersionWorker.perform_async change['id']
    end
  end
  tag.errback do
    STDOUT.puts "tag _changes feed died"
    EM.stop
  end
}
