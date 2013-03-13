ENV['RACK_ENV'] = 'test'

require 'bundler/setup'
require 'keyspace/client'
require 'keyspace/server'
require 'rack/test'
require 'logger'

require 'coveralls'
Coveralls.wear!

set :environment, :test
set :run, false
set :raise_errors, true

RSpec.configure do |config|
  config.include Rack::Test::Methods
end
