require 'forwardable'
require 'net/http'

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

      # Save this bucket to the server
      def save
        uri = URI(Vault::Client.url)
        uri.path = "/buckets"

        response = Net::HTTP.post_form(uri, :verifycap => verifycap)
        response.code == 201
      end

      # Save this bucket and raise an exception if the save fails
      def save!
        raise "couldn't save bucket: #{response.code} #{response.message}" unless save
        true
      end
    end
  end
end
