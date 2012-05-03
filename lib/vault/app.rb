require 'sinatra'

module Vault
  class App < Sinatra::Base
    get '/' do
      "Hello, world!"
    end

    post '/:id' do
      halt 400, "no key given" unless params[:key]

      bucket = Bucket.new(params[:key])
      halt 400, "invalid bucket id" unless bucket.id == params[:id]
      bucket.save

      201
    end
  end
end
