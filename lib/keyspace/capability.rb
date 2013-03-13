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

      if secret_key
        hkdf = HKDF.new(@secret_key, :algorithm => 'SHA256')
        @name_siv_key = hkdf.next_bytes(32)
        @name_key     = hkdf.next_bytes(SECRET_KEY_BYTES)
        @value_key    = hkdf.next_bytes(SECRET_KEY_BYTES)
      else
        @name_siv_key = nil
        @name_key     = nil
        @value_key    = nil
      end
    end

    # Encrypt a name/value pair for insertion into Keyspace
    def encrypt(name, value, timestamp = Time.now)
      raise InvalidCapabilityError, "don't have write capability" unless @signing_key
      raise ArgumentError, "name too long" if name.to_s.size > MAX_NAME_LENGTH

      pack_signed_nvpair(encrypt_name(name.to_s), encrypt_value(value.to_s), timestamp)
    end

    # Decrypt an encrypted value, checking its authenticity with the verify key
    def decrypt(message)
      raise InvalidCapabilityError, "don't have read capability" unless secret_key
      encrypted_name, encrypted_value, timestamp = unpack_signed_nvpair(message)

      [decrypt_name(encrypted_name), decrypt_value(encrypted_value), timestamp]
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
    def pack_signed_nvpair(encrypted_name, encrypted_value, timestamp)
      message   = [
        encrypted_name.bytesize, 
        encrypted_name,
        encrypted_value.bytesize,
        encrypted_value,
        timestamp.utc.to_i
      ].pack("na*na*Q")

      signature = @signing_key.sign(message)
      signature + message
    end

    # Parse an encrypted value into its constituent components
    def unpack_signed_nvpair(message)
      verify!(message)
      signature, name_size, rest       = message.unpack("a#{SIGNATURE_BYTES}na*")
      encrypted_name, value_size, rest = rest.unpack("a#{name_size}na*") 
      encrypted_value, timestamp       = rest.unpack("a#{value_size}Q")

      [encrypted_name, encrypted_value, Time.at(timestamp)]
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

    # Encrypt names of name/value pairs using Synthetic IVs (SIV)
    # SIV is CPA secure, but gives us deterministic encryption for
    # the keys of interest. This allows someone else with the same
    # key to calculate a deterministic ciphertext representing the
    # name of a name/value pair. This keeps names of name/value pairs
    # secure while allowing clients to request specific encrypted keys
    def encrypt_name(name)
      raise InvalidCapabilityError, "don't have read capability" unless @name_key
      name = name.to_s
      
      # Use HKDF as our SIV PRG
      hkdf  = HKDF.new(name, :iv => @name_siv_key, :algorithm => 'SHA256')
      nonce = hkdf.next_bytes(NONCE_BYTES)

      ciphertext = Crypto::SecretBox.new(@name_key).encrypt(nonce, name)
      nonce + ciphertext
    end

    # Decrypt a SIV-encrypted name
    def decrypt_name(message)
      nonce, ciphertext = message[0,NONCE_BYTES], message[NONCE_BYTES..-1]
      Crypto::SecretBox.new(@name_key).decrypt(nonce, ciphertext)
    end

    # Encrypt a value with a random nonce
    def encrypt_value(value)
      nonce      = Crypto::Random.random_bytes(NONCE_BYTES)
      ciphertext = Crypto::SecretBox.new(@value_key).encrypt(nonce, value)

      nonce + ciphertext
    end

    # Decrypt a value with a random nonce
    def decrypt_value(message)
      nonce, ciphertext = message[0,NONCE_BYTES], message[NONCE_BYTES..-1]
      Crypto::SecretBox.new(@value_key).decrypt(nonce, ciphertext)
    end
  end
end
