require 'spec_helper'

describe "Bucket integration" do
  let(:example_port) { 12345 }
  let(:example_url)  { "http://127.0.0.1:#{example_port}/" }
  let(:example_bucket) { :foobar }

  before :all do
    Keyspace::Server::Bucket.store = Keyspace::Server::Backend::Redis.new(Redis.new(:db => 10))

    Keyspace::Server::App.set(:port, example_port)
    @thread = Thread.new { Keyspace::Server::App.run! }
    sleep 0.5 # hax!
    Thread.pass until @thread.status && @thread.status == "sleep"

    Keyspace::Client.url = example_url
  end

  after :all do
    @thread.kill
  end

  it "creates buckets" do
    # Ensure there's no bucket left over in Redis
    begin
      Keyspace::Server::Bucket.delete(example_bucket)
    rescue Keyspace::BucketNotFoundError
    end

    Keyspace::Client::Bucket.create(example_bucket).save
    Keyspace::Server::Bucket.get(example_bucket).should be_a Keyspace::Server::Bucket
  end
end
