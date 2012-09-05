require 'spec_helper'

describe "Bucket integration" do
  let(:example_port) { 12345 }
  let(:example_url)  { "http://127.0.0.1:#{example_port}/" }
  let(:example_bucket) { :foobar }

  before :all do
    Vault::Server::Bucket.store = Vault::Server::Backend::Redis.new(Redis.new(:db => 10))

    Vault::Server::App.set(:port, example_port)
    @thread = Thread.new { Vault::Server::App.run! }
    sleep 0.1 # hax!
    Thread.pass until @thread.status && @thread.status == "sleep"

    Vault::Client.url = example_url
  end

  after :all do
    @thread.kill
  end

  it "creates buckets" do
    # Ensure there's no bucket left over in Redis
    begin
      Vault::Server::Bucket.delete(example_bucket)
    rescue Vault::BucketNotFoundError
    end

    Vault::Client::Bucket.create(example_bucket).save
    Vault::Server::Bucket.get(example_bucket).should be_a Vault::Server::Bucket
  end
end
