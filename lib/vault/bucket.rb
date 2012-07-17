require 'openssl'
require 'fileutils'
require 'digest/sha2'

module Vault
  class InvalidCapabilityError < ArgumentError; end # potentially forged credentials
  class InvalidSignatureError  < ArgumentError; end # potentially forged data

  class Bucket
    attr_reader :id, :capabilities, :path
    attr_reader :public_key, :encryption_key, :signature_key

    # Generate a completely new bucket
    def self.create
      signature_key  = SignatureAlgorithm.generate_key
      encryption_key = Vault.random_bytes(32)

      new(signature_key, encryption_key)
    end

    # Instantiate a bucket from its constituent keys
    def initialize(signature_key, encryption_key = nil)
      @signature_key, @encryption_key = signature_key, encryption_key
      @public_key = SignatureAlgorithm.public_key(signature_key)
      @signature_key = nil if @signature_key == @public_key

      # We might consider using HMAC here
      @id = Digest::SHA256.hexdigest(@public_key)
    end

    # Encrypt a key/value pair for insertion into the vault
    # Key is not a cryptographic key, but a human meaningful name that this
    # data should be associated with
    def encrypt(key, value, timestamp = Time.now)
      raise ArgumentError, "key too long" if key.size > 0xFF

      cipher = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
      cipher.encrypt

      cipher.key = @encryption_key
      cipher.iv  = iv = cipher.random_iv

      ciphertext =  cipher.update(value)
      ciphertext << cipher.final

      # TODO: hash/encrypt key
      message   = [key.size, key, timestamp.utc.to_i, iv, ciphertext.size, ciphertext].pack("CA*QA16NA*")
      signature = SignatureAlgorithm.sign(@signature_key, message)
      [signature.size, signature, message].pack("CA*A*")
    end

    # Determine if the given encrypted value is authentic
    def verify(encrypted_value)
      signature_size, rest = encrypted_value.unpack("CA*")
      signature, message = rest.unpack("A#{signature_size}A*")

      SignatureAlgorithm.verify(@signature_key, message, signature)
    end

    # Decrypt an encrypted value, checking its authenticity with the bucket's verify key
    def decrypt(encrypted_value)
      raise InvalidCapabilityError, "don't have read capability for this bucket" unless @encryption_key
      raise InvalidSignatureError, "potentially forged data: signature mismatch" unless verify(encrypted_value)

      signature_size, rest = encrypted_value.unpack("CA*")
      signature, key_size, rest = rest.unpack("A#{signature_size}CA*")
      key, timestamp, iv, message_size, ciphertext = rest.unpack("A#{key_size}QA16NA*")

      # Cast to Time from an integer timestamp
      timestamp = Time.at(timestamp)

      cipher = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
      cipher.decrypt

      cipher.key = @encryption_key
      cipher.iv  = iv

      plaintext = cipher.update(ciphertext)
      plaintext << cipher.final

      [key, plaintext, timestamp]
    end

    def inspect
      "#<#{self.class} #{@id} [#{@capabilities.join(' ')}]}>"
    end

    # Save a newly created bucket to disk
    def save
      path.mkdir
      path.chmod 0700
      path.join('verify.key').open('w', 0600) { |f| f << @public_key }
    end

    def destroy
      FileUtils.rm_r path
    end

    def path
      @path ||= Vault.bucket_path.join(@id)
    end
  end
end
