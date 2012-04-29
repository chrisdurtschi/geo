require 'hashie'

module Geo
  Config = Hashie::Mash.new(
    host: ENV['GEOSERVER_HOST'],
    port: ENV['GEOSERVER_PORT'],
    db:   ENV['GEOSERVER_DB'],
  )
  Config.url = "http://#{Config.host}:#{Config.port}/#{Config.db}"
end
