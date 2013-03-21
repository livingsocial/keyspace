require 'forwardable'

module Keyspace
  module Server
    class Vault
      extend Forwardable
      def_delegators :@capability, :id, :capabilities

      class << self
        # Persistence layer for vaults
        attr_accessor :store

        # Generate a completely new vault
        def create(verifycap)
          # TODO: check for existing vaults
          verifycap = Capability.parse(verifycap) if verifycap.is_a? String
          store["verifycap:#{verifycap.id}"] = verifycap.to_s
          new verifycap
        end

        # Find an existing vault by its ID
        def get(vault_id)
          verifycap = store["verifycap:#{vault_id}"]
          raise VaultNotFoundError, "no such vault: #{vault_id}" unless verifycap

          new(verifycap)
        end

        # Delete a vault by its ID
        def delete(vault_id)
          # TODO: delete vault contents
          store.delete("verifycap:#{vault_id}")
        end
      end

      # Load a vault from a capability string
      def initialize(capability_string)
        @capability = Capability.parse(capability_string)
      end

      # Retrieve an encrypted value from a vault
      def get(name)
        self.class.store["value:#{id}:#{name}"]
      end
      alias_method :[], :get

      # Store an encrypted value in this vault
      def put(message)
        # TODO: check timestamp against existing values to prevent replay attacks
        encrypted_name, encrypted_value, timestamp = Message.unpack(@capability, message)
        self.class.store["value:#{id}:#{encrypted_name}"] = message
      end
      alias_method :[]=, :put

      def inspect
        "#<#{self.class}:#{id} #{@capability}>"
      end
    end
  end
end
