require 'pathname'
require 'openssl'
require 'keyspace/version'

require 'keyspace/capability'
require 'keyspace/signature_algorithm'

module Keyspace
  # Couldn't find the requested bucket
  class BucketNotFoundError < StandardError; end

  def self.bucket_path
    @bucket_path ||= Pathname.new File.expand_path('../../buckets', __FILE__)
  end

  # Secure random data
  def self.random_bytes(size)
    OpenSSL::Random.random_bytes(size)
  end
end
