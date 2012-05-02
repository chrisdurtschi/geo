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
    capture_url  = "#{Geo::Config.url}/#{id}/original.jpg"
    response     = Excon.get capture_url, expects: 200
    File.open(capture_path, 'wb') do |file|
      file.write response.body
    end

    tag_path = File.join(tmp_path, "tag.jpg")
    tag_url  = "#{Geo::Config.url}/#{capture['tag_id']}/original.jpg"
    response = Excon.get tag_url, expects: 200
    File.open(tag_path, 'wb') do |file|
      file.write response.body
    end

    cvoutput = `python #{File.expand_path(File.dirname(__FILE__))}/match.py #{capture_path} #{tag_path}`.strip
    STDOUT.puts "CV Output: #{cvoutput}"

    match = Yajl::Parser.parse(cvoutput)
    capture['match'] = match

    FileUtils.rm_rf tmp_path

    Excon.put "#{Geo::Config.url}/#{id}?rev=#{capture['_rev']}",
              body: Yajl::Encoder.encode(capture),
              headers: {'Content-Type' => 'application/json'},
              expects: [200, 201]
  end
end
