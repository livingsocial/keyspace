require 'securerandom'
require 'openssl'
require 'red25519'
require 'hkdf'
require 'base32'

module Keyspace
  # Something requires a capability we don't have
  class InvalidCapabilityError < StandardError; end

  # Potentially forged data: data does not match signature
  class InvalidSignatureError < StandardError; end

  # Capabilities provide access to encrypted data
  class Capability
    # Use AES256 with CBC padding
    SYMMETRIC_CIPHER = "aes-256-cbc"

    # Size of the symmetric key used for encrypting contents
    SYMMETRIC_KEY_BYTES = 32
    
    # Maximum length of a key (as in key/value pair) name
    MAX_KEY_LENGTH = 256

    attr_reader :id, :signature_key, :verify_key, :encryption_key, :capabilities

    # Generate a new writecap. Note: id is not authenticated
    def self.generate(id)
      signature_key = Ed25519::SigningKey.generate.to_bytes
      hkdf = HKDF.new SecureRandom.random_bytes(SYMMETRIC_KEY_BYTES)
      encryption_key = hkdf.next_bytes(SYMMETRIC_KEY_BYTES)

      new(id, 'rw', signature_key, encryption_key)
    end

    # Parse a capability token into a capability object
    def self.parse(capability_string)
      matches = capability_string.to_s.match(/^(\w+):(\w+)@(.*)/)
      id, caps, keys = matches[1], matches[2], Base32.decode(matches[3].upcase)

      case caps
      when 'r', 'rw'
        encryption_key, signature_key = keys.unpack("a#{SYMMETRIC_KEY_BYTES}a*")
      when 'v'
        encryption_key, signature_key = nil, keys
      else raise ArgumentError, "invalid capability level: #{caps}"
      end

      new(id, caps, signature_key, encryption_key)
    end

    def initialize(id, caps, signature_key, encryption_key = nil)
      @id, @capabilities, @encryption_key = id, caps, encryption_key
      
      if caps.include?('w')
        @signature_key = Ed25519::SigningKey.new(signature_key)
        @verify_key = @signature_key.verify_key
      else
        @signature_key = nil
        @verify_key = Ed25519::VerifyKey.new(signature_key)
      end
    end

    # Encrypt a key/value pair for insertion into Keyspace
    # Key is not a cryptographic key, but a human meaningful id that this
    # data should be associated with
    def encrypt(key, value, timestamp = Time.now)
      raise InvalidCapabilityError, "don't have write capability" unless @signature_key
      raise ArgumentError, "key too long" if key.to_s.size > MAX_KEY_LENGTH

      cipher = OpenSSL::Cipher::Cipher.new(SYMMETRIC_CIPHER)
      cipher.encrypt

      cipher.key = encryption_key
      cipher.iv  = iv = cipher.random_iv

      ciphertext =  cipher.update(value)
      ciphertext << cipher.final

      # TODO: hash/encrypt key
      message   = [key.size, key.to_s, timestamp.utc.to_i, iv, ciphertext.size, ciphertext].pack("Ca*Qa16Na*")
      signature = @signature_key.sign(message)
      signature + message
    end

    # Determine if the given encrypted value is authentic
    def verify(encrypted_value)
      signature, message = encrypted_value.unpack("a#{Ed25519::SIGNATURE_BYTES}a*")
      @verify_key.verify(signature, message)
    end

    # Decrypt an encrypted value, checking its authenticity with the verify key
    def decrypt(encrypted_value)
      raise InvalidCapabilityError, "don't have read capability" unless encryption_key
      raise InvalidSignatureError, "potentially forged data: signature mismatch" unless verify(encrypted_value)

      signature, key_size, rest = encrypted_value.unpack("a#{Ed25519::SIGNATURE_BYTES}Ca*")
      key, timestamp, iv, message_size, ciphertext = rest.unpack("a#{key_size}Qa16Na*")

      # Cast to Time from an integer timestamp
      timestamp = Time.at(timestamp)

      cipher = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
      cipher.decrypt

      cipher.key = encryption_key
      cipher.iv  = iv

      plaintext = cipher.update(ciphertext)
      plaintext << cipher.final

      [key, plaintext, timestamp]
    end

    # Degrade this capability to a lower level
    def degrade(new_capability)
      case new_capability
      when :r, :read, :readcap
        raise InvalidCapabilityError, "don't have read capability" unless @encryption_key
        self.class.new(@id, 'r', @verify_key.to_bytes, @encryption_key)
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
      keys = encryption_key || ""
      
      if @signature_key
        keys += @signature_key.to_bytes
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
