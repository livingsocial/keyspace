require 'openssl'

module Vault
  # Pubkey signature algorithm (ECDSA)
  class SignatureAlgorithm
    # "128-bit" equivalent security with 512-bit (64-byte) signatures
    GROUP = "secp256k1"

    # Generate a new ECDSA private key
    def self.generate_key
      ec = OpenSSL::PKey::EC.new(GROUP)
      ec.generate_key
      ec.to_der
    end

    def initialize(key)
      @key = OpenSSL::PKey::EC.new(key)
      @key.public_key = key unless @key.private_key?
    end

    def private_key?; @key.private_key?; end

    def public_key
      if @key.private_key?
        pkey = OpenSSL::PKey::EC.new(GROUP)
        pkey.public_key = @key.public_key
        pkey.to_der
      else
        @key.to_der
      end
    end

    def sign(data)
      @key.dsa_sign_asn1(data)
    end

    def verify(data, signature)
      @key.dsa_verify_asn1(data, signature)
    end
  end
end
