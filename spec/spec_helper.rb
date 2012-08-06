require 'bundler/setup'
require 'vault/server'
require 'sinatra'
require 'rack/test'

set :environment, :test
set :run, false
set :raise_errors, true
set :logging, true

RSpec.configure do |config|
  config.include Rack::Test::Methods
end
