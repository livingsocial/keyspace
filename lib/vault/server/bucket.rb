require 'openssl'
require 'fileutils'

module Vault
  class InvalidCapabilityError < ArgumentError; end # potentially forged credentials
  class InvalidSignatureError  < ArgumentError; end # potentially forged data

  class Bucket
    extend Forwardable
    def_delegators :@capability, :id, :signature_key, :encryption_key, :capabilities
    def_delegators :@capability, :encrypt, :verify, :decrypt, :public_key

    # Generate a completely new bucket
    def self.create(id)
      new(Vault::Capability.generate(id).to_s)
    end

    # Load a bucket from a capability string
    def initialize(capability_string)
      @capability = Capability.parse(capability_string)
    end

    def inspect
      "#<#{self.class} #{self.class.capability_string(id, signature_key, encryption_key)}>"
    end

    # Save a newly created bucket to disk
    def save
      path.mkdir
      path.chmod 0700
      path.join('verify.key').open('w', 0600) { |f| f << public_key }
    end

    def destroy
      FileUtils.rm_r path
    end

    def path
      @path ||= Vault.bucket_path.join(id)
    end
  end
end
