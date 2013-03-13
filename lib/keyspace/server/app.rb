require 'sinatra'
require 'keyspace/server'

module Keyspace
  module Server
    class App < Sinatra::Base
      post '/vaults' do
        halt 400, "no verifycap given" unless params[:verifycap]

        Vault.create(params[:verifycap])
        201
      end

      get '/vaults/:vault/:name' do
        begin
          name = Base32.decode(params[:name])
        rescue => ex
          halt 404
        end

        begin
          vault = Vault.get(params[:vault])
        rescue Keyspace::VaultNotFoundError
          halt 404
        end

        ciphertext = vault.get(name)
        halt 404 unless ciphertext

        [200, {"Content-Type" => Keyspace::MIME_TYPE}, ciphertext]
      end

      put '/vaults/:vault' do
        begin
          vault = Vault.get(params[:vault])
        rescue Keyspace::VaultNotFoundError
          halt 404
        end

        body   = request.body.read

        vault.put(body)
        200
      end
      
      delete '/vaults/:vault' do
        Keyspace::Server::Vault.delete(params[:vault])  
        200
      end
    end
  end
end
