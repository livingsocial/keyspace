require 'forwardable'

module Keyspace
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
          verifycap = store.verifycap(bucket_id)
          raise BucketNotFoundError, "no such bucket: #{bucket_id}" unless verifycap

          new(verifycap)
        end

        # Delete a bucket by its ID
        def delete(bucket_id)
          store.delete(bucket_id)
        end
      end

      # Load a bucket from a capability string
      def initialize(capability_string)
        @capability = Capability.parse(capability_string)
      end

      # Retrieve an encrypted value from a bucket
      def get(key)
        self.class.store.get(id, key.to_s)
      end
      alias_method :[], :get

      # Store an encrypted value in this bucket
      def put(ciphertext)
        if @capability.verify(ciphertext)
          # TODO: encapsulate this logic somewhere better (in Capability perhaps?)
          signature_size, rest = ciphertext.unpack("CA*")
          signature, key_size, rest = rest.unpack("a#{signature_size}Ca*")
          key = rest[0...key_size]

          self.class.store.put(id, key, ciphertext)
        else
          raise InvalidSignatureError, "potentially forged data: signature mismatch"
        end
      end
      alias_method :[]=, :put

      def inspect
        "#<#{self.class} #{id} #{@capability}>"
      end
    end
  end
end
