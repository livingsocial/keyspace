require 'sinatra'

module Vault
  class App < Sinatra::Base
    post '/:id' do
      halt 400, "no key given" unless params[:key]

      begin
        bucket = Bucket.new(params[:id], params[:key])
        bucket.save
      rescue => ex
        p ex
      end

      201
    end
  end
end
