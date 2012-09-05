require 'keyspace'
require 'keyspace/client/bucket'
require 'uri'

module Keyspace
  module Client
    class << self
      # URL of the Keyspace server we're talking to
      attr_accessor :url
    end
  end
end
