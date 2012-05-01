require 'openssl'
require 'fileutils'

module Vault
  class Bucket
    attr_reader :id, :capabilities, :path

    class InvalidCapabilityError < ArgumentError; end

    # Generate a new bucket
    def self.create
      signing_key = OpenSSL::PKey::DSA.new(2048)

      # TODO: address potential length extension attack
      read_key = Digest::SHA256.hexdigest(signing_key.to_der)

      new(signing_key.public_key.to_der, read_key, signing_key.to_der).tap do |bucket|
        bucket.save
      end
    end

    def initialize(verify_key, read_key = nil, signing_key = nil)
      if signing_key
        if read_key && read_key != Digest::SHA256.hexdigest(signing_key)
          raise InvalidCapabilityError, "read key does not match signing key"
        end

        @signing_key = OpenSSL::PKey::DSA.new(signing_key)

        if @signing_key.public_key.to_der != verify_key
          raise InvalidCapabilityError, "verify key does not match signing key"
        end
      else
        @signing_key = nil
      end

      @verify_key = OpenSSL::PKey::DSA.new(verify_key)
      @read_key   = [read_key].pack("H*") if read_key

      # TODO: address potential length extension attack
      @id = Digest::SHA256.hexdigest(@verify_key.to_der)

      @capabilities = []
      @capabilities << :read   if @read_key
      @capabilities << :write  if @signing_key
      @capabilities << :verify if @verify_key
    end

    def inspect
      "#<#{self.class} #{@id} [#{@capabilities.join(' ')}]}>"
    end

    def save
      path.mkdir
      path.join('verify.key').open('w', 0600) { |f| f << @verify_key.to_der }
    end

    def destroy
      FileUtils.rm_r path
    end

    def path
      @path ||= Vault.bucket_path.join(@id)
    end
  end
end
