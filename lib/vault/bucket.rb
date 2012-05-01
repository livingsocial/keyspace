require 'openssl'
require 'fileutils'

module Vault
  class Bucket
    attr_reader :id, :capabilities, :path

    class InvalidCapabilityError < ArgumentError; end # potentially forged credentials
    class InvalidSignatureError < ArgumentError; end  # potentially forged data

    # Generate a completely new bucket
    def self.create
      signing_key = OpenSSL::PKey::DSA.new(2048)

      # TODO: address potential length extension attack
      read_key = Digest::SHA256.hexdigest(signing_key.to_der)

      new(signing_key.public_key.to_der, read_key, signing_key.to_der).tap do |bucket|
        bucket.save
      end
    end

    # Instantiate a bucket from its constituent keys
    def initialize(verify_key, read_key = nil, signing_key = nil)
      if signing_key
        if read_key && read_key != Digest::SHA256.hexdigest(signing_key)
          raise InvalidCapabilityError, "read key does not match signing key"
        end

        @signing_key = OpenSSL::PKey::DSA.new(signing_key)

        if @signing_key.public_key.to_der != verify_key
          raise InvalidCapabilityError, "potentially forged credentials: verify key does not match signing key"
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

    # Encrypt a key/value pair for insertion into the vault
    # Key is not a cryptographic key, but a human meaningful name that this
    # data should be associated with
    def encrypt(key, value, timestamp = Time.now)
      raise ArgumentError, "key too long" if key.size > 0xFF

      cipher = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
      cipher.encrypt

      # TODO: KDF w\ a random salt here perhaps?
      cipher.key = @read_key
      cipher.iv  = iv = cipher.random_iv

      ciphertext =  cipher.update(value)
      ciphertext << cipher.final

      # TODO: hash/encrypt key
      # TODO: Y2038 compliance o_O
      message   = [key.size, key, timestamp.utc.to_i, iv, ciphertext.size, ciphertext].pack("CA*NA16NA*")
      signature = @signing_key.syssign Digest::SHA1.digest(message)
      [signature.size, signature, message].pack("CA*A*")
    end

    # Decrypt an encrypted value, checking its authenticity with the bucket's verify key
    def decrypt(encrypted_value)
      signature_size, rest = encrypted_value.unpack("CA*")
      signature, message = rest.unpack("A#{signature_size}A*")
      digest = Digest::SHA1.digest(message)

      unless @verify_key.sysverify(digest, signature)
        raise InvalidSignatureError, "potentially forged data: signature mismatch"
      end

      key_size, rest = message.unpack("CA*")
      key, timestamp, iv, message_size, ciphertext = rest.unpack("A#{key_size}NA16NA*")

      # Cast to Time from an integer timestamp
      timestamp = Time.at(timestamp)

      cipher = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
      cipher.decrypt

      cipher.key = @read_key
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
