require 'fileutils'
require 'tmpdir'
require 'yajl/http_stream'
require 'excon'
require 'sidekiq'

require File.join(File.dirname(__FILE__), '..', 'config')

$stdout.sync = true

class ImageVersionWorker
  include Sidekiq::Worker

  VERSIONS = {
    capture: {
      normalized: "-resize 640x640",
    },
    tag: {
      icon_ldpi: "-resize 24x24",
      icon_mdpi: "-resize 32x32",
      icon_hdpi: "-resize 48x48",
      icon_xdpi: "-resize 64x64",
      transparent_ldpi: "-alpha set -channel A -evaluate set 50% -resize 240x240",
      transparent_mdpi: "-alpha set -channel A -evaluate set 50% -resize 320x320",
      transparent_hdpi: "-alpha set -channel A -evaluate set 50% -resize 480x480",
      transparent_xdpi: "-alpha set -channel A -evaluate set 50% -resize 640x640",
      normalized: "-resize 640x640",
    }
  }

  FORMATS = {
    capture: {},
    tag: {
      transparent_ldpi: "png",
      transparent_mdpi: "png",
      transparent_hdpi: "png",
      transparent_xdpi: "png",
    }
  }

  def perform(id)
    @id = id
    response = Excon.get "#{Geo::Config.url}/#{@id}"
    @doc = Yajl::Parser.parse response.body
    STDOUT.puts "Got a document: #{@doc.inspect}"

    return if @doc['error']

    @rev  = @doc['_rev']
    @type = @doc['type'].to_sym
    versions!
    FileUtils.rm_rf(@tmp_path)
  end

  def versions!
    download
    VERSIONS[@type].keys.each do |ver|
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
    command = VERSIONS[@type][@version]
    @format = FORMATS[@type][@version] || 'jpg'
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
