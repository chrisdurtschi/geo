require 'yajl'
require 'em-http'

require File.join(File.dirname(__FILE__), 'config')
require File.join(File.dirname(__FILE__), 'workers')

$stdout.sync = true

EM.run {
  capture_url = "#{Geo::Config.url}/_changes?feed=continuous&heartbeat=2000&filter=app/unmatched_captures"
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


  images_url = "#{Geo::Config.url}/_changes?feed=continuous&heartbeat=2000&filter=app/new_images"
  STDOUT.puts "Starting to listen to images URL #{images_url}"

  images = EM::HttpRequest.new(images_url).get inactivity_timeout: 0
  images.stream do |chunk|
    next if chunk.strip == ""

    STDOUT.puts "Got a _changes update: #{chunk}"
    change = Yajl::Parser.parse chunk

    if change && change['id'] && !change['deleted']
      ImageVersionWorker.perform_async change['id']
    end
  end
  images.errback do
    STDOUT.puts "images _changes feed died"
    EM.stop
  end
}
