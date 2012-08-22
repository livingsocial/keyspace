require 'forwardable'

module Vault
  module Server
    class Bucket
      extend Forwardable
      def_delegators :@capability, :id, :capabilities

      class << self
        # Persistence layer for buckets
        attr_accessor :store

        # Generate a completely new bucket
        def create(verifycap)
          # TODO: check for existing buckets
          store.create(verifycap)
          new verifycap
        end

        # Find an existing bucket by its ID
        def get(bucket_id)
          new store.verifycap(bucket_id)
        end
      end

      # Load a bucket from a capability string
      def initialize(capability_string)
        @capability = Capability.parse(capability_string)
      end

      # Store an encrypted value in this bucket
      def put(ciphertext)
        if @capability.verify(ciphertext)
          self.class.store.put(ciphertext)
        else
          raise InvalidSignatureError, "potentially forged data: signature mismatch"
        end
      end

      def inspect
        "#<#{self.class} #{id} #{@capability}>"
      end
    end
  end
end
