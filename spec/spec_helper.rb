require 'bundler/setup'
require 'keyspace/client'
require 'keyspace/server'
require 'rack/test'

require 'coveralls'
Coveralls.wear!

set :environment, :test
set :run, false
set :raise_errors, true
set :logging, true

RSpec.configure do |config|
  config.include Rack::Test::Methods
end
