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

      @capabilities = 'r'
      @capabilities << 'w' if SignatureAlgorithm.new(signature_key).private_key?
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
