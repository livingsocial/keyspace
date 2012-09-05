require 'redis'

module Keyspace
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
          @redis.set verifycap_key(verifycap.id), verifycap
        end

        # Delete a bucket
        def delete(bucket_id)
          verifycap_key = verifycap_key(bucket_id)
          verifycap = @redis.get verifycap_key
          raise BucketNotFoundError, "no such bucket: #{bucket_id}" unless verifycap

          # TODO: delete bucket contents
          @redis.del verifycap_key
        end

        # Obtain the stored verifycap for a given bucket
        def verifycap(bucket_id)
          @redis.get verifycap_key(bucket_id)
        end

        # Retrieve a value from the bucket
        # No verification of authenticity is performed as it should be
        # performed by Keyspace::Server prior to storage
        def get(bucket, key)
          @redis.get value_key(bucket, key)
        end

        # Put a value in a bucket
        # No verification of authenticity is performed as it should be
        # performed by Keyspace::Server prior to storage
        def put(bucket, key, value)
          @redis.set value_key(bucket, key), value
        end

      private

        # Obtain the redis key name for a given verifycap
        def verifycap_key(bucket_id)
          "verifycap::#{bucket_id}"
        end

        # Obtain the key name for a particular bucket/key pair
        def value_key(bucket, key)
          "value::#{bucket}:#{key}"
        end
      end
    end
  end
end
