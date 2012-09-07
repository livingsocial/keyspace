require 'spec_helper'

describe "Bucket integration" do
  let(:example_port)   { 12345 }
  let(:example_url)    { "http://127.0.0.1:#{example_port}/" }

  let(:example_bucket) { "foobar" }
  let(:example_key)    { "qux" }
  let(:example_value)  { "This is an example value" }

  before :all do
    Keyspace::Server::Bucket.store = Keyspace::Server::Backend::Redis.new(Redis.new(:db => 10))

    Keyspace::Server::App.set(:port, example_port)
    @thread = Thread.new { Keyspace::Server::App.run! }
    sleep 0.5 # hax!
    Thread.pass until @thread.status && @thread.status == "sleep"

    Keyspace::Client.url = example_url
  end

  before :each do
    # Ensure there's no bucket left over in Redis
    begin
      Keyspace::Server::Bucket.delete(example_bucket)
    rescue Keyspace::BucketNotFoundError
    end
  end

  after :all do
    @thread.kill
  end

  it "creates buckets" do
    Keyspace::Client::Bucket.create(example_bucket).save
    Keyspace::Server::Bucket.get(example_bucket).should be_a Keyspace::Server::Bucket
  end

  it "stores data in buckets" do
    bucket = Keyspace::Client::Bucket.create(example_bucket)
    bucket.save!

    bucket[:foo] = example_value
    bucket.save!

    bucket[:foo].should eq example_value
  end
end
