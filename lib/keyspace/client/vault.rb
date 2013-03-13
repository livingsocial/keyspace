require 'forwardable'
require 'net/http'

module Keyspace
  module Client
    class Vault
      attr_reader :capability

      extend Forwardable
      def_delegators :@capability, :id, :capabilities

      # Generate a completely new vault
      def self.create(id)
        new(Keyspace::Capability.generate(id).to_s, true)
      end

      # Load a vault from a capability string
      def initialize(capability_string, new_vault = false)
        @capability = Capability.parse(capability_string)
        @new_vault = new_vault
        @changes = {}
      end

      def inspect
        "#<#{self.class} #{@capability}>"
      end

      # Obtain the verifycap for this vault
      def verifycap
        @capability.degrade(:verify)
      end

      # Retrieve a value from keyspace
      def get(name)
        encrypted_name = Base32.encode(@capability.encrypt_name(name))

        uri = URI(Keyspace::Client.url)
        uri.path = "/vaults/#{id}/#{encrypted_name}"

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

      # Store a value in the vault
      # Values are not persisted until #save is called
      def put(key, value)
        if @capability.writecap?
          @changes[key] = value
        else raise InvalidCapabilityError, "don't have write capability for this vault"
        end
      end
      alias_method :[]=, :put

      # Save this vault and raise an exception if the save fails
      def save!
        uri = URI(Keyspace::Client.url)

        if new_vault?
          uri.path = "/vaults"

          response = Net::HTTP.post_form(uri, :verifycap => verifycap)

          if response.code == "201"
            @new_vault = false
            true
          else raise VaultError, "couldn't save vault: #{response.code} #{response.message}"
          end
        end

        if !@changes.empty?
          uri.path = "/vaults/#{id}"

          # TODO: real bulk API
          @changes.each do |key, value|
            http = Net::HTTP.new(uri.host, uri.port)

            request = Net::HTTP::Put.new(uri.request_uri)
            request.body = @capability.encrypt(key, value)
            request['Content-Type'] = Keyspace::MIME_TYPE

            response = http.request request
            unless response.code == "200"
              raise VaultError, "couldn't save `#{key}' to vault `#{id}': #{response.code} #{response.message}"
            end
          end

          @changes = {}
        end

        true
      end

      # Save this vault to the server
      def save
        save!
      rescue
        false
      end

      # Is this a new vault which hasn't been saved to the server yet?
      def new_vault?; @new_vault; end
      
      # Delete this vault from the server
      def delete
        raise VaultError, "can't delete new vaults" if new_vault?
        
        uri  = URI(Keyspace::Client.url)
        http = Net::HTTP.new(uri.host, uri.port)
        
        request  = Net::HTTP::Delete.new("/vaults/#{id}")
        response = http.request request
        unless response.code == "200"
          raise VaultError, "couldn't delete vault #{id}: #{response.code} #{response.message}"
        end
        
        true
      end
    end
  end
end
