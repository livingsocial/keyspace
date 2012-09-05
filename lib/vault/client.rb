require 'vault'
require 'vault/client/bucket'
require 'uri'

module Vault
  module Client
    class << self
      # URL of the Vault server we're talking to
      attr_accessor :url
    end
  end
end
