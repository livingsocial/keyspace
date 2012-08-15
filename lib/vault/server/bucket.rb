require 'forwardable'

module Vault
  module Server
    class Bucket
      extend Forwardable
      def_delegators :@capability, :id, :capabilities

      # Generate a completely new bucket
      def self.create(verifycap)
        new(verifycap)
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