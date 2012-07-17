require 'openssl'

module Vault
  # Pubkey signature algorithm (ECDSA)
  module SignatureAlgorithm
    # "128-bit" equivalent security with 512-bit (64-byte) signatures
    GROUP = "secp256k1"

    # Generate a new ECDSA private key
    def self.generate_key
      ec = OpenSSL::PKey::EC.new(GROUP)
      ec.generate_key
      ec.to_der
    end

    def self.public_key(key)
      ec   = OpenSSL::PKey::EC.new(key)

      if ec.private_key?
        pkey = OpenSSL::PKey::EC.new(GROUP)
        pkey.public_key = ec.public_key
        pkey.to_der
      else
        key
      end
    end

    def self.sign(private_key, data)
      ec = OpenSSL::PKey::EC.new(private_key)
      ec.dsa_sign_asn1(data)
    end

    def self.verify(public_key, data, signature)
      ec = OpenSSL::PKey::EC.new(public_key)
      ec.dsa_verify_asn1(data, signature)
    end
  end
end
