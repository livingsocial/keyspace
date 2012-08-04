require 'base32'

module Vault
  # Capabilities provide access to encrypted data
  class Capability
    attr_reader :id, :signature_key, :encryption_key, :capabilities

    # Generate a brand new capability. Note: id is not authenticated
    def self.generate(id)
      signature_key  = SignatureAlgorithm.generate_key
      encryption_key = Vault.random_bytes(SYMMETRIC_KEY_SIZE / 8)

      new(id, signature_key, encryption_key)
    end

    def self.parse(capability_string)
      matches = capability_string.match(/^(\w+):\w+@(.*)/)

      id, keys = matches[1], Base32.decode(matches[2].upcase)
      encryption_key, signature_key = keys.unpack("a#{SYMMETRIC_KEY_SIZE/8}a*")

      new(id, signature_key, encryption_key)
    end

    def initialize(id, signature_key, encryption_key = nil)
      @id, @signature_key, @encryption_key = id, signature_key, encryption_key
      @signer = SignatureAlgorithm.new(signature_key)

      @capabilities = 'r'
      @capabilities << 'w' if SignatureAlgorithm.new(signature_key).private_key?
    end

    # TODO: replace this with a proper capability degrading method
    def public_key
      @signer.public_key
    end

    # Encrypt a key/value pair for insertion into the vault
    # Key is not a cryptographic key, but a human meaningful id that this
    # data should be associated with
    def encrypt(key, value, timestamp = Time.now)
      raise InvalidCapabilityError, "don't have write capability" unless @signer.private_key?
      raise ArgumentError, "key too long" if key.size > 0xFF

      cipher = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
      cipher.encrypt

      cipher.key = encryption_key
      cipher.iv  = iv = cipher.random_iv

      ciphertext =  cipher.update(value)
      ciphertext << cipher.final

      # TODO: hash/encrypt key
      message   = [key.size, key, timestamp.utc.to_i, iv, ciphertext.size, ciphertext].pack("CA*QA16NA*")
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
      raise InvalidCapabilityError, "don't have read capability for this bucket" unless encryption_key
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

    def to_s
      keys32 = Base32.encode(encryption_key + signature_key).downcase.sub(/=+$/, '')
      "#{id}:#{capabilities}@#{keys32}"
    end

    def inspect
      "#<#{self.class} #{to_s}>"
    end
  end
end
