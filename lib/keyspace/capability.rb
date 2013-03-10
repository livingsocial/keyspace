require 'rbnacl'
require 'base32'

module Keyspace
  # Something requires a capability we don't have
  class InvalidCapabilityError < StandardError; end

  # Potentially forged data: data does not match signature
  class InvalidSignatureError < StandardError; end

  # Capabilities provide access to encrypted data
  class Capability
    # Size of the symmetric key (32-bytes)
    SECRET_KEY_BYTES = Crypto::NaCl::SECRETKEYBYTES

    # Number of bytes in a nonce used by SecretBox (24-bytes)
    NONCE_BYTES      = Crypto::NaCl::NONCEBYTES

    # Number of bytes in Ed25519 signatures (64-bytes)
    SIGNATURE_BYTES  = Crypto::NaCl::SIGNATUREBYTES

    # Maximum length of a name (as in name/value pair)
    MAX_NAME_LENGTH  = 256

    attr_reader :id, :signing_key, :verify_key, :secret_key, :capabilities

    # Generate a new writecap. Note: id is not authenticated
    def self.generate(id)
      signing_key  = Crypto::SigningKey.generate.to_bytes
      secret_key = Crypto::Random.random_bytes(SECRET_KEY_BYTES)

      new(id, 'rw', signing_key, secret_key)
    end

    # Parse a capability token into a capability object
    def self.parse(capability_string)
      matches = capability_string.to_s.match(/^(\w+):(\w+)@(.*)/)
      id, caps, keys = matches[1], matches[2], Base32.decode(matches[3].upcase)

      case caps
      when 'r', 'rw'
        secret_key, signing_key = keys.unpack("a#{SECRET_KEY_BYTES}a*")
      when 'v'
        secret_key, signing_key = nil, keys
      else raise ArgumentError, "invalid capability level: #{caps}"
      end

      new(id, caps, signing_key, secret_key)
    end

    def initialize(id, caps, signing_key, secret_key = nil)
      @id, @capabilities, @secret_key = id, caps, secret_key
      
      if caps.include?('w')
        @signing_key = Crypto::SigningKey.new(signing_key)
        @verify_key = @signing_key.verify_key
      else
        @signing_key = nil
        @verify_key = Crypto::VerifyKey.new(signing_key)
      end
    end

    # Encrypt a name/value pair for insertion into Keyspace
    def encrypt(name, value, timestamp = Time.now)
      raise InvalidCapabilityError, "don't have write capability" unless @signing_key
      raise ArgumentError, "name too long" if name.to_s.size > MAX_NAME_LENGTH

      box = Crypto::SecretBox.new(secret_key)

      # With 192-bits of potential nonce space, we're fairly safe
      # from collisions simply by using a random nonce
      nonce = Crypto::Random.random_bytes(NONCE_BYTES)
      ciphertext = box.encrypt(nonce, value)

      pack_value(name, timestamp, nonce, ciphertext)
    end

    # Decrypt an encrypted value, checking its authenticity with the verify key
    def decrypt(encrypted_value)
      raise InvalidCapabilityError, "don't have read capability" unless secret_key
      name, timestamp, nonce, ciphertext = unpack_value(encrypted_value)

      box = Crypto::SecretBox.new(secret_key)
      plaintext = box.decrypt(nonce, ciphertext)

      [name, plaintext, timestamp]
    end

    # Determine if the given encrypted value is authentic
    def verify(encrypted_value)
      signature, message = encrypted_value.unpack("a#{SIGNATURE_BYTES}a*")
      @verify_key.verify(message, signature)
    end

    # Verify which raises if the signature doesn't match
    def verify!(encrypted_value)
      verify(encrypted_value) or raise InvalidSignatureError, "potentially forged data: signature mismatch"
    end

    # Pack an encrypted value into its serialized representation
    def pack_value(name, timestamp, nonce, ciphertext)
      # TODO: hash/encrypt name
      name = name.to_s

      message   = [name.bytesize, name, timestamp.utc.to_i, nonce, ciphertext].pack("Ca*Qa#{NONCE_BYTES}a*")
      signature = @signing_key.sign(message)
      signature + message
    end

    # Parse an encrypted value into its constituent components
    def unpack_value(encrypted_value)
      verify!(encrypted_value)
      signature, key_size, rest = encrypted_value.unpack("a#{SIGNATURE_BYTES}Ca*")
      name, timestamp, nonce, ciphertext = rest.unpack("a#{key_size}Qa#{NONCE_BYTES}a*")

      [name, Time.at(timestamp), nonce, ciphertext]
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
      keys = secret_key || ""
      
      if @signing_key
        keys += @signing_key.to_bytes
      else
        keys += @verify_key.to_bytes
      end
      
      keys32 = Base32.encode(keys).downcase.sub(/=+$/, '')
      "#{id}:#{capabilities || 'v'}@#{keys32}"
    end

    def inspect
      "#<#{self.class} #{to_s}>"
    end
  end
end
