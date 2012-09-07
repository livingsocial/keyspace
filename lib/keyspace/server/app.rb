require 'sinatra'
require 'keyspace/server'

module Keyspace
  module Server
    class App < Sinatra::Base
      post '/buckets' do
        halt 400, "no verifycap given" unless params[:verifycap]

        Bucket.create(params[:verifycap])
        201
      end

      get '/buckets/:bucket/:key' do
        begin
          bucket = Bucket.get(params[:bucket])
        rescue Keyspace::BucketNotFoundError
          halt 404
        end

        ciphertext = bucket.get(params[:key])
        halt 404 unless ciphertext

        [200, {"Content-Type" => Keyspace::MIME_TYPE}, ciphertext]
      end

      put '/buckets/:bucket' do
        begin
          bucket = Bucket.get(params[:bucket])
        rescue Keyspace::BucketNotFoundError
          halt 404
        end

        body   = request.body.read

        bucket.put(body)
        200
      end
    end
  end
end
