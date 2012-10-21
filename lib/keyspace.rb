require 'pathname'
require 'openssl'

require 'keyspace/version'
require 'keyspace/capability'

module Keyspace
  # Generic errors surrounding buckets
  class BucketError < StandardError; end

  # Couldn't find the requested bucket
  class BucketNotFoundError < BucketError; end

  # Couldn't find the requested key
  class KeyNotFoundError < BucketError; end

  # MIME type used for bucket values
  MIME_TYPE = "application/octet-stream"

  def self.bucket_path
    @bucket_path ||= Pathname.new File.expand_path('../../buckets', __FILE__)
  end

  # Secure random data
  def self.random_bytes(size)
    OpenSSL::Random.random_bytes(size)
  end
end
