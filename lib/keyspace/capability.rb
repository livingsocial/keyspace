require 'rbnacl'
require 'base32'
require 'hkdf'

module Keyspace
  # Something requires a capability we don't have
  class InvalidCapabilityError < StandardError; end

  # Potentially forged data: data does not match signature
  class InvalidSignatureError < StandardError; end

  # Capabilities provide access to encrypted data
  class Capability
    attr_reader :id, :verify_key, :capabilities

    # Generate a new writecap. Note: id is not authenticated
    def self.generate(id)
      signing_key  = Crypto::SigningKey.generate.to_bytes
      secret_key = Crypto::Random.random_bytes(SECRET_KEY_BYTES)

      new(id, 'rw', signing_key, secret_key)
    end

    # Parse a capability token into a capability object
    def self.parse(capability_string)
      matches = capability_string.to_s.match(/\Aks\.(\w+):(\w+)@(.*)\Z/)
      scheme, vault, keys = matches[1], matches[2], Base32.decode(matches[3].upcase)

      caps = "v"

      case scheme
      when 'write', 'read'
        secret_key, signing_key = keys.unpack("a#{SECRET_KEY_BYTES}a*")
        caps << "r"
        caps << "w" if scheme == 'write'
      when 'verify'
        secret_key, signing_key = nil, keys
      else raise ArgumentError, "invalid capability URI: #{capability_string}"
      end

      new(vault, caps, signing_key, secret_key)
    end

    def initialize(id, caps, signing_key, secret_key = nil)
      @id, @capabilities, @secret_key = id, caps, secret_key
      
      if caps.include?('w')
        @signing_key = Crypto::SigningKey.new(signing_key)
        @verify_key  = @signing_key.verify_key
      else
        @signing_key = nil
        @verify_key  = Crypto::VerifyKey.new(signing_key)
      end
    end

    # Return the signing key if we have write capability
    def signing_key
      @signing_key or raise InvalidCapabilityError, "don't have write capability"
    end

    # Return the secret key if we have read capability
    def secret_key
      @secret_key or raise InvalidCapabilityError, "don't have read capability"
    end

    # Encrypt a message with this capability
    def encrypt(message)
      message.encrypt(self)
    end

    # Decrypt a message with this capability
    def decrypt(encrypted_message)
      Message.decrypt(self, encrypted_message)
    end

    # Degrade this capability to a lower level
    def degrade(new_capability)
      case new_capability
      when :r, :read, :readcap
        raise InvalidCapabilityError, "don't have read capability" unless @secret_key
        self.class.new(@id, 'r', @verify_key.to_bytes, @secret_key)
      when :v, :verify, :verifycap
        self.class.new(@id, 'v', @verify_key.to_bytes)
      else raise ArgumentError, "invalid capability: #{new_capability}"
      end
    end

    # Is this a write capability?
    def writecap?
      @capabilities.include?('w')
    end

    # Is this a read capability?
    def readcap?
      @capabilities.include?('r')
    end

    # Is this a verify capability?
    def verifycap?
      readcap? || @capabilities.include?('v')
    end

    # Generate a token out of this capability
    def to_s
      if writecap?
        scheme = "ks.write"
      elsif readcap?
        scheme = "ks.read"
      else
        scheme = "ks.verify"
      end

      keys = @secret_key || ""
      
      if @signing_key
        keys += @signing_key.to_bytes
      else
        keys += @verify_key.to_bytes
      end
      
      keys32 = Base32.encode(keys).downcase.sub(/=+$/, '')
      "#{scheme}:#{id}@#{keys32}"
    end

    def inspect
      "#<#{self.class} #{to_s}>"
    end
  end
end
