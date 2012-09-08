require 'forwardable'
require 'net/http'

module Keyspace
  module Client
    class Bucket
      attr_reader :capability

      extend Forwardable
      def_delegators :@capability, :id, :capabilities

      # Generate a completely new bucket
      def self.create(id)
        new(Keyspace::Capability.generate(id).to_s, true)
      end

      # Load a bucket from a capability string
      def initialize(capability_string, new_bucket = false)
        @capability = Capability.parse(capability_string)
        @new_bucket = new_bucket
        @changes = {}
      end

      def inspect
        "#<#{self.class} #{@capability}>"
      end

      # Obtain the verifycap for this bucket
      def verifycap
        @capability.degrade(:verify)
      end

      # Retrieve a value from keyspace
      def get(key)
        uri = URI(Keyspace::Client.url)
        uri.path = "/buckets/#{id}/#{key}"

        http = Net::HTTP.new(uri.host, uri.port)
        response = http.request Net::HTTP::Get.new(uri.request_uri)

        if response.code == "200"
          key, value, timestamp = @capability.decrypt(response.body)
          value
        elsif response.code == "404"
          nil
        else raise KeyNotFoundError, "couldn't get key: #{response.code} #{response.message}"
        end
      end
      alias_method :[], :get

      # Store a value in the bucket
      # Values are not persisted until #save is called
      def put(key, value)
        if @capability.writecap?
          @changes[key] = value
        else raise InvalidCapabilityError, "don't have write capability for this bucket"
        end
      end
      alias_method :[]=, :put

      # Save this bucket and raise an exception if the save fails
      def save!
        uri = URI(Keyspace::Client.url)

        if new_bucket?
          uri.path = "/buckets"

          response = Net::HTTP.post_form(uri, :verifycap => verifycap)

          if response.code == "201"
            @new_bucket = false
            true
          else raise BucketError, "couldn't save bucket: #{response.code} #{response.message}"
          end
        end

        if !@changes.empty?
          uri.path = "/buckets/#{id}"

          # TODO: real bulk API
          @changes.each do |key, value|
            http = Net::HTTP.new(uri.host, uri.port)

            request = Net::HTTP::Put.new(uri.request_uri)
            request.body = @capability.encrypt(key, value)
            request['Content-Type'] = Keyspace::MIME_TYPE

            response = http.request request
            unless response.code == "200"
              puts response.body
              raise BucketError, "couldn't save `#{key}' to bucket `#{id}': #{response.code} #{response.message}"
            end
          end

          @changes = {}
        end

        true
      end

      # Save this bucket to the server
      def save
        save!
      rescue
        false
      end

      # Is this a new bucket which hasn't been saved to the server yet?
      def new_bucket?; @new_bucket; end
    end
  end
end
