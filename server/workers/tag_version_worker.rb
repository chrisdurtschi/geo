require 'fileutils'
require 'tmpdir'
require 'yajl/http_stream'
require 'excon'
require 'sidekiq'

require File.join(File.dirname(__FILE__), '..', 'config')

$stdout.sync = true

class TagVersionWorker
  include Sidekiq::Worker

  VERSIONS = {
    icon_ldpi: "-resize 24x24",
    icon_mdpi: "-resize 32x32",
    icon_hdpi: "-resize 48x48",
    transparent_ldpi: "-resize 240x240 -alpha set -channel A -evaluate set 50%",
    transparent_mdpi: "-resize 320x320 -alpha set -channel A -evaluate set 50%",
    transparent_hdpi: "-resize 480x480 -alpha set -channel A -evaluate set 50%",
  }

  FORMATS = {
    transparent_ldpi: "png",
    transparent_mdpi: "png",
    transparent_hdpi: "png",
  }

  def perform(id)
    @id = id
    response = Excon.get "#{Geo::Config.url}/#{@id}"
    tag = Yajl::Parser.parse response.body
    STDOUT.puts "Got a Tag: #{tag.inspect}"
    if tag
      @rev = tag['_rev']
      versions!
    end
  end

  def versions!
    download
    VERSIONS.keys.each do |ver|
      @version = ver
      version
      upload
    end
  end

 private

  def download
    @tmp_path = File.join(Dir.tmpdir, @id)
    FileUtils.mkdir_p @tmp_path
    @original = "#{@tmp_path}/original.jpg"
    @get_url  = "#{Geo::Config.url}/#{@id}/original.jpg"

    response = Excon.get(@get_url)
    File.open(@original, 'wb') do |file|
      file.write response.body
    end

    STDOUT.puts "Downloaded #{@get_url}"
  end

  def version
    command = VERSIONS[@version]
    @format = FORMATS[@version] || 'jpg'
    @versioned = "#{@tmp_path}/#{@version}.#{@format}"
    result = `convert #{@original} #{command} #{@versioned}`
    STDOUT.puts "Attempted versioning #{@original} with #{command}: #{result}"
  end

  def upload
    @put_url = "#{Geo::Config.url}/#{@id}/#{@version}.#{@format}?rev=#{@rev}"
    STDOUT.puts "Uploading #{@versioned} to #{@put_url}"

    response = Excon.put(@put_url, body: File.open(@versioned), headers: {"Content-Type" => "image/#{@format}"})
    body = Yajl::Parser.parse response.body
    @rev = body['rev']

    STDOUT.puts "Uploaded #{@versioned} and got new revision #{@rev}"
  end
end
