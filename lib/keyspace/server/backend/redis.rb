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

        # Create a new vault
        def create(verifycap)
          verifycap = Capability.parse(verifycap) if verifycap.is_a? String

          # TODO: check if vault already exists
          @redis.set verifycap_key(verifycap.id), verifycap
        end

        # Delete a vault
        def delete(vault_id)
          verifycap_key = verifycap_key(vault_id)
          verifycap = @redis.get verifycap_key
          raise VaultNotFoundError, "no such vault: #{vault_id}" unless verifycap

          # TODO: delete vault contents
          @redis.del verifycap_key
        end

        # Obtain the stored verifycap for a given vault
        def verifycap(vault_id)
          @redis.get verifycap_key(vault_id)
        end

        # Retrieve a value from the vault
        # No verification of authenticity is performed as it should be
        # performed by Keyspace::Server prior to storage
        def get(vault, key)
          @redis.get value_key(vault, key)
        end

        # Put a value in a vault
        # No verification of authenticity is performed as it should be
        # performed by Keyspace::Server prior to storage
        def put(vault, key, value)
          @redis.set value_key(vault, key), value
        end

      private

        # Obtain the redis key name for a given verifycap
        def verifycap_key(vault_id)
          "verifycap::#{vault_id}"
        end

        # Obtain the key name for a particular vault/key pair
        def value_key(vault, key)
          "value::#{vault}:#{key}"
        end
      end
    end
  end
end
