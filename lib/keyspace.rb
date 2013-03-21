require 'keyspace/version'
require 'keyspace/capability'
require 'keyspace/message'

module Keyspace
  # Generic errors surrounding vaults
  class VaultError < StandardError; end

  # Couldn't find the requested vault
  class VaultNotFoundError < VaultError; end

  # Couldn't find the requested key
  class KeyNotFoundError < VaultError; end

  # MIME type used for vault values
  MIME_TYPE = "application/octet-stream"

  # Number of bytes in Ed25519 signatures (64-bytes)
  SIGNATURE_BYTES  = Crypto::NaCl::SIGNATUREBYTES

  # Size of the symmetric key (32-bytes)
  SECRET_KEY_BYTES = Crypto::NaCl::SECRETKEYBYTES

  # Number of bytes in a nonce used by SecretBox (24-bytes)
  NONCE_BYTES = Crypto::NaCl::NONCEBYTES
end
