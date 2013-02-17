require 'rbnacl'
require 'base32'
require 'openssl'

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

    # Number of bytes in signatures
    SIGNATURE_BYTES = Crypto::NaCl::SIGNATUREBYTES

    # Maximum length of a key (as in key/value pair) name
    MAX_NAME_LENGTH = 256

    attr_reader :id, :signature_key, :verify_key, :encryption_key, :capabilities

    # Generate a new writecap. Note: id is not authenticated
    def self.generate(id)
      signature_key  = Crypto::SigningKey.generate.to_bytes
      encryption_key = Crypto::Random.random_bytes(32)

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
        @signature_key = Crypto::SigningKey.new(signature_key)
        @verify_key = @signature_key.verify_key
      else
        @signature_key = nil
        @verify_key = Crypto::VerifyKey.new(signature_key)
      end
    end

    # Encrypt a name/value pair for insertion into Keyspace
    def encrypt(name, value, timestamp = Time.now)
      raise InvalidCapabilityError, "don't have write capability" unless @signature_key
      raise ArgumentError, "name too long" if name.to_s.size > MAX_NAME_LENGTH

      cipher = OpenSSL::Cipher::Cipher.new(SYMMETRIC_CIPHER)
      cipher.encrypt

      cipher.key = encryption_key
      cipher.iv  = iv = cipher.random_iv

      ciphertext =  cipher.update(value)
      ciphertext << cipher.final

      pack_value(name, timestamp, iv, ciphertext)
    end

    # Decrypt an encrypted value, checking its authenticity with the verify key
    def decrypt(encrypted_value)
      raise InvalidCapabilityError, "don't have read capability" unless encryption_key
      name, timestamp, nonce, ciphertext = unpack_value(encrypted_value)

      cipher = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
      cipher.decrypt

      cipher.key = encryption_key
      cipher.iv  = nonce

      plaintext = cipher.update(ciphertext)
      plaintext << cipher.final

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

      message   = [name.bytesize, name, timestamp.utc.to_i, nonce, ciphertext].pack("Ca*Qa16a*")
      signature = @signature_key.sign(message)
      signature + message
    end

    # Parse an encrypted value into its constituent components
    def unpack_value(encrypted_value)
      verify!(encrypted_value)
      signature, key_size, rest = encrypted_value.unpack("a#{SIGNATURE_BYTES}Ca*")
      name, timestamp, nonce, ciphertext = rest.unpack("a#{key_size}Qa16a*")

      [name, Time.at(timestamp), nonce, ciphertext]
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
