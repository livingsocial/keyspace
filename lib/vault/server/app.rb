require 'sinatra'

module Vault
  module Server
    class App < Sinatra::Base
      post '/buckets' do
        halt 400, "no verifycap given" unless params[:verifycap]

        Bucket.create(params[:verifycap])
        201
      end
    end
  end
end
