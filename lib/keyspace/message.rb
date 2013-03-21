require 'hkdf'

module Keyspace
  class Message
    # Maximum length of a name (as in name/value pair)
    MAX_NAME_LENGTH  = 256

    class << self
      # Determine if the given encrypted value is authentic
      def verify(capability, encrypted_message)
        signature, message = encrypted_message.unpack("a#{SIGNATURE_BYTES}a*")
        capability.verify_key.verify(message, signature)
      end

      # Verify which raises if the signature doesn't match
      def verify!(capability, encrypted_message)
        verify(capability, encrypted_message) or raise InvalidSignatureError, "potentially forged data: signature mismatch"
      end

      # Pack an encrypted value into its serialized representation
      def pack(capability, encrypted_name, encrypted_value, timestamp)
        message = [
          encrypted_name.bytesize,
          encrypted_name,
          encrypted_value.bytesize,
          encrypted_value,
          timestamp.to_i
        ].pack("na*na*Q")

        signature = capability.signing_key.sign(message)
        signature + message
      end

      # Obtain the encrypted version of a given name
      def encrypted_name(capability, name)
        Encryption.encrypt_name(capability.secret_key, name.to_s)
      end

      # Verify and unpack an encrypted message into its ciphertexts
      def unpack(capability, encrypted_message)
        verify!(capability, encrypted_message)

        signature, name_size, rest       = encrypted_message.unpack("a#{SIGNATURE_BYTES}na*")
        encrypted_name, value_size, rest = rest.unpack("a#{name_size}na*")
        encrypted_value, timestamp       = rest.unpack("a#{value_size}Q")

        [encrypted_name, encrypted_value, Time.at(timestamp)]
      end

      # Decrypt an encrypted message into a Message object
      def decrypt(capability, encrypted_message)
        encrypted_name, encrypted_value, timestamp = unpack(capability, encrypted_message)

        name  = Encryption.decrypt_name(capability.secret_key, encrypted_name)
        value = Encryption.decrypt_value(capability.secret_key, encrypted_value)

        # FIXME: Time.at returns local time
        new(name, value, timestamp)
      end
    end

    attr_reader :name, :value, :timestamp

    def initialize(name, value, timestamp = Time.now)
      raise ArgumentError, "name too long" if name.to_s.size > MAX_NAME_LENGTH

      @name, @value, @timestamp = name.to_s, value.to_s, timestamp
    end

    # Encrypt a name/value pair for insertion into Keyspace
    def encrypt(capability)
      encrypted_name  = Encryption.encrypt_name(capability.secret_key, @name)
      encrypted_value = Encryption.encrypt_value(capability.secret_key, @value)

      self.class.pack(capability, encrypted_name, encrypted_value, timestamp)
    end

    # Raw encryption operations for names and values
    module Encryption
      module_function

      # Encrypt names of name/value pairs using Synthetic IVs (SIV)
      # SIV is CPA secure, but gives us deterministic encryption for
      # the keys of interest. This allows someone else with the same
      # key to calculate a deterministic ciphertext representing the
      # name of a name/value pair. This keeps names of name/value pairs
      # secure while allowing clients to request specific encrypted keys
      def encrypt_name(secret_key, name)
        keys = kdf(secret_key)

        # Use HKDF as our SIV PRG
        hkdf  = HKDF.new(name, :iv => keys[:name_siv_key], :algorithm => 'SHA256')
        nonce = hkdf.next_bytes(NONCE_BYTES)

        ciphertext = Crypto::SecretBox.new(keys[:name_key]).encrypt(nonce, name)
        nonce + ciphertext
      end

      # Decrypt a SIV-encrypted name
      def decrypt_name(secret_key, encrypted_name)
        name_key   = kdf(secret_key)[:name_key]
        nonce      = encrypted_name[0, NONCE_BYTES]
        ciphertext = encrypted_name[NONCE_BYTES..-1]

        Crypto::SecretBox.new(name_key).decrypt(nonce, ciphertext)
      end

      # Encrypt a value with a random nonce
      def encrypt_value(secret_key, value)
        value_key  = kdf(secret_key)[:value_key]
        nonce      = Crypto::Random.random_bytes(NONCE_BYTES)

        ciphertext = Crypto::SecretBox.new(value_key).encrypt(nonce, value)
        nonce + ciphertext
      end

      # Decrypt a value with a random nonce
      def decrypt_value(secret_key, message)
        value_key  = kdf(secret_key)[:value_key]
        nonce      = message[0, NONCE_BYTES]
        ciphertext = message[NONCE_BYTES..-1]
        Crypto::SecretBox.new(value_key).decrypt(nonce, ciphertext)
      end

      def kdf(secret_key)
        hkdf = HKDF.new(secret_key, :algorithm => 'SHA256')

        name_siv_key = hkdf.next_bytes(32)
        name_key     = hkdf.next_bytes(SECRET_KEY_BYTES)
        value_key    = hkdf.next_bytes(SECRET_KEY_BYTES)

        {
          :name_siv_key => name_siv_key,
          :name_key     => name_key,
          :value_key    => value_key
        }
      end
    end
  end
end