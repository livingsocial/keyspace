require 'pathname'
require 'openssl'
require 'vault/version'

require 'vault/capability'
require 'vault/signature_algorithm'

module Vault
  # Use AES256 with CBC padding
  SYMMETRIC_CIPHER = "aes-256-cbc"

  # Size of the symmetric key used for encrypting contents
  SYMMETRIC_KEY_SIZE = 256

  def self.bucket_path
    @bucket_path ||= Pathname.new File.expand_path('../../buckets', __FILE__)
  end

  # Secure random data
  def self.random_bytes(size)
    OpenSSL::Random.random_bytes(size)
  end
end
