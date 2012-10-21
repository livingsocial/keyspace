require 'keyspace/version'
require 'keyspace/capability'

module Keyspace
  # Generic errors surrounding vaults
  class VaultError < StandardError; end

  # Couldn't find the requested vault
  class VaultNotFoundError < VaultError; end

  # Couldn't find the requested key
  class KeyNotFoundError < VaultError; end

  # MIME type used for vault values
  MIME_TYPE = "application/octet-stream"
end
