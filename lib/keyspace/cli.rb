require 'thor'

module Keyspace
  class CLI < Thor
    desc :server, "Start the Keyspace server"
    def server
      require 'keyspace/server/app'
      Server::App.run!
    end
  end
end