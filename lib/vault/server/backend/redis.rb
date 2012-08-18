require 'redis'

module Vault
  module Server
    module Backend
      class Redis
        attr_reader :redis

        # Create a new Redis adapter from a redis-rb duck type
        def initialize(redis)
          @redis = redis
        end

        # Create a new bucket
        def create(verifycap)
          verifycap = Capability.parse(verifycap) if verifycap.is_a? String

          # TODO: check if bucket already exists
          @redis.set("verifycap::#{verifycap.id}", verifycap)
        end

        # Retrieve a value from the bucket
        # No verification of authenticity is performed as it should be
        # performed by Vault::Server prior to storage
        def get(bucket, key)
          @redis.get(key_name(bucket, key))
        end

        # Put a value in a bucket
        # No verification of authenticity is performed as it should be
        # performed by Vault::Server prior to storage
        def set(bucket, key, value)
          @redis.set(key_name(bucket, key), value)
        end

      private

        # Obtain the key name for a particular bucket/key pair
        def key_name(bucket, key)
          "value::#{bucket}:#{key}"
        end
      end
    end
  end
end
