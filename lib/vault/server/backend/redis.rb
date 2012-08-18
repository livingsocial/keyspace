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
          @redis.set(verifycap.id, verifycap)
        end
      end
    end
  end
end
