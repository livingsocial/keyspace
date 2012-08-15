require 'bundler/setup'
require 'vault/client'
require 'vault/server'
require 'rack/test'

set :environment, :test
set :run, false
set :raise_errors, true
set :logging, true

RSpec.configure do |config|
  config.include Rack::Test::Methods
end
