require 'fileutils'
require 'tmpdir'
require 'yajl/http_stream'
require 'excon'
require 'sidekiq'

require File.join(File.dirname(__FILE__), '..', 'config')

$stdout.sync = true

class ImageVersionWorker
  include Sidekiq::Worker

  CROPPED = "-gravity Center -crop %{length}x%{length}+0+0 +repage".freeze

  VERSIONS = {
    capture: {
      cropped: CROPPED,
      normalized: "#{CROPPED} -resize 640x640",
    },
    tag: {
      cropped: CROPPED,
      icon_ldpi: "#{CROPPED} -resize 24x24",
      icon_mdpi: "#{CROPPED} -resize 32x32",
      icon_hdpi: "#{CROPPED} -resize 48x48",
      icon_xdpi: "#{CROPPED} -resize 64x64",
      normalized: "#{CROPPED} -resize 640x640",
    }
  }

  FORMATS = {
    capture: {},
    tag: {}
  }

  def perform(id)
    @id = id
    response = Excon.get "#{Geo::Config.url}/#{@id}"
    @doc = Yajl::Parser.parse response.body
    STDOUT.puts "Got a document: #{@doc.inspect}"

    return if @doc['error']

    @rev  = @doc['_rev']
    @type = @doc['type'].to_sym

    @params = {length: @doc['original_height']}
    @params[:length] = @doc['original_width'] if @doc['original_width'] < @params[:length]

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
    command = VERSIONS[@type][@version] % @params
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
