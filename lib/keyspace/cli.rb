require 'thor'

module Keyspace
  class CLI < Thor
    desc :server, "Start the Keyspace server"
    def server
      require 'keyspace/server/app'

      # TODO: configurable backends
      Server::Bucket.store = Server::Backend::Redis.new(Redis.new)
      Server::App.run!
    end
  end
end
