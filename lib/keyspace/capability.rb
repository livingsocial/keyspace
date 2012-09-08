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
    SYMMETRIC_KEY_SIZE = 256

    # Maximum length of a key (as in key/value pair) name
    MAX_KEY_LENGTH = 256

    attr_reader :id, :signature_key, :encryption_key, :capabilities

    # Generate a brand new capability. Note: id is not authenticated
    def self.generate(id)
      signature_key  = SignatureAlgorithm.generate_key
      encryption_key = Keyspace.random_bytes(SYMMETRIC_KEY_SIZE / 8)

      new(id, signature_key, encryption_key)
    end

    # Parse a capability token into a capability object
    def self.parse(capability_string)
      matches = capability_string.to_s.match(/^(\w+):(\w+)@(.*)/)
      id, caps, keys = matches[1], matches[2], Base32.decode(matches[3].upcase)

      case caps
      when 'r', 'rw'
        encryption_key, signature_key = keys.unpack("a#{SYMMETRIC_KEY_SIZE/8}a*")
      when 'v'
        encryption_key, signature_key = nil, keys
      else raise ArgumentError, "invalid capability level: #{caps}"
      end

      new(id, signature_key, encryption_key)
    end

    def initialize(id, signature_key, encryption_key = nil)
      @id, @signature_key, @encryption_key = id, signature_key, encryption_key
      @signer = SignatureAlgorithm.new(signature_key)

      if encryption_key
        @capabilities = 'r'
        @capabilities << 'w' if @signer.private_key?
      else
        @capabilities = 'v'
      end
    end

    # Encrypt a key/value pair for insertion into Keyspace
    # Key is not a cryptographic key, but a human meaningful id that this
    # data should be associated with
    def encrypt(key, value, timestamp = Time.now)
      raise InvalidCapabilityError, "don't have write capability" unless @signer.private_key?
      raise ArgumentError, "key too long" if key.to_s.size > MAX_KEY_LENGTH

      cipher = OpenSSL::Cipher::Cipher.new(SYMMETRIC_CIPHER)
      cipher.encrypt

      cipher.key = encryption_key
      cipher.iv  = iv = cipher.random_iv

      ciphertext =  cipher.update(value)
      ciphertext << cipher.final

      # TODO: hash/encrypt key
      message   = [key.size, key.to_s, timestamp.utc.to_i, iv, ciphertext.size, ciphertext].pack("CA*QA16NA*")
      signature = @signer.sign(message)
      [signature.size, signature, message].pack("Ca*a*")
    end

    # Determine if the given encrypted value is authentic
    def verify(encrypted_value)
      signature_size, rest = encrypted_value.unpack("Ca*")
      signature, message = rest.unpack("A#{signature_size}A*")

      @signer.verify(message, signature)
    end

    # Decrypt an encrypted value, checking its authenticity with the bucket's verify key
    def decrypt(encrypted_value)
      raise InvalidCapabilityError, "don't have read capability" unless encryption_key
      raise InvalidSignatureError, "potentially forged data: signature mismatch" unless verify(encrypted_value)

      signature_size, rest = encrypted_value.unpack("CA*")
      signature, key_size, rest = rest.unpack("a#{signature_size}Ca*")
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
        self.class.new(@id, @signer.public_key, @encryption_key)
      when :v, :verify, :verifycap
        self.class.new(@id, @signer.public_key)
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
      @capabilities.include?('r') || @capabilities.include?('v')
    end

    # Generate a token out of this capability
    def to_s
      keys = encryption_key ? encryption_key + signature_key : signature_key
      keys32 = Base32.encode(keys).downcase.sub(/=+$/, '')
      "#{id}:#{capabilities || 'v'}@#{keys32}"
    end

    def inspect
      "#<#{self.class} #{to_s}>"
    end
  end
end
