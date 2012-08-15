require 'forwardable'

module Vault
  module Client
    class Bucket
      extend Forwardable
      def_delegators :@capability, :id, :capabilities

      # Generate a completely new bucket
      def self.create(id)
        new(Vault::Capability.generate(id).to_s)
      end

      # Load a bucket from a capability string
      def initialize(capability_string)
        @capability = Capability.parse(capability_string)
      end

      def inspect
        "#<#{self.class} #{id} #{@capability}>"
      end

      # Obtain the verifycap for this bucket
      def verifycap
        @capability.degrade(:verify)
      end
    end
  end
end
