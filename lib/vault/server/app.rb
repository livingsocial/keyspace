require 'sinatra'
require 'vault/server'

module Vault
  module Server
    class App < Sinatra::Base
      post '/buckets' do
        halt 400, "no verifycap given" unless params[:verifycap]

        Bucket.create(params[:verifycap])
        201
      end

      put '/buckets/:bucket' do
        bucket = Bucket.get(params[:bucket])
        body   = request.body.read

        bucket.put(body)
        200
      end
    end
  end
end
