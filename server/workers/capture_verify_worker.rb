require 'fileutils'
require 'tmpdir'
require 'yajl'
require 'excon'
require 'sidekiq'

require File.join(File.dirname(__FILE__), '..', 'config')

$stdout.sync = true

class CaptureVerifyWorker
  include Sidekiq::Worker

  def perform(id)
    response = Excon.get "#{Geo::Config.url}/#{id}", expects: 200
    capture  = Yajl::Parser.parse response.body

    tmp_path = File.join(Dir.tmpdir, id)
    FileUtils.mkdir_p tmp_path

    capture_path = File.join(tmp_path, "capture.jpg")
    capture_url  = "#{Geo::Config.url}/#{id}/normalized.jpg"
    response     = Excon.get capture_url, expects: 200
    File.open(capture_path, 'wb') do |file|
      file.write response.body
    end

    tag_path = File.join(tmp_path, "tag.jpg")
    tag_url  = "#{Geo::Config.url}/#{capture['tag_id']}/normalized.jpg"
    response = Excon.get tag_url, expects: 200
    File.open(tag_path, 'wb') do |file|
      file.write response.body
    end

    cvoutput = `python #{File.expand_path(File.dirname(__FILE__))}/match.py #{capture_path} #{tag_path}`.strip
    STDOUT.puts "CV Output: #{cvoutput}"

    match = Yajl::Parser.parse(cvoutput)
    image = match.delete 'image'

    if rect = match['min_rect']
      distances = []
      perfect   = [[0,0],[640,0],[640,640],[0,640]]
      rect.each_with_index do |coord, i|
        x, y   = coord
        px, py = perfect[i]
        distances << Math.sqrt((px - x)**2 + (py - y)**2)
      end
      average  = distances.inject(0) { |r,e| r+=e } / 4.0
      accuracy = (640.0 - average) / 640.0
      accuracy = 0 if accuracy < 0
      match['accuracy'] = accuracy
    end

    capture['match'] = match

    url = "#{Geo::Config.url}/#{id}"
    STDOUT.puts "PUTting #{capture} to #{url}"

    response = Excon.put url,
                  body: Yajl::Encoder.encode(capture),
                  headers: {'Content-Type' => 'application/json'},
                  expects: [200, 201]

    body = Yajl::Parser.parse response.body

    if image
      url = "#{Geo::Config.url}/#{id}/match.jpg?rev=#{body['rev']}"
      STDOUT.puts "Uploading match to #{url}"

      response = Excon.put url,
                    body: File.open(image),
                    headers: {"Content-Type" => "image/jpg"},
                    expects: [200, 201]
      body = Yajl::Parser.parse response.body

      STDOUT.puts "Finished uploading match: #{body}"
    end

    FileUtils.rm_rf tmp_path
  end
end
