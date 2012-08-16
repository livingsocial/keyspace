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
          store.create(verifycap)
          new(verifycap)
        end
      end

      # Load a bucket from a capability string
      def initialize(capability_string)
        @capability = Capability.parse(capability_string)
      end

      def inspect
        "#<#{self.class} #{id} #{@capability}>"
      end
    end
  end
end
