require 'spec_helper'

describe Keyspace::Server::Bucket do
  let(:example_bucket) { :foobar }
  let(:example_key)    { :baz }
  let(:example_value)  { 'quux' }

  let(:writecap)       { Keyspace::Capability.generate(example_bucket) }
  let(:verifycap)      { writecap.degrade(:verify) }
  let(:bucket_store)   { mock(:store) }

  before :each do
    Keyspace::Server::Bucket.store = bucket_store
  end

  it "creates buckets from verifycaps" do
    bucket_store.should_receive(:create).with(verifycap)
    Keyspace::Server::Bucket.create(verifycap).should be_a Keyspace::Server::Bucket
  end

  it "deletes buckets" do
    bucket_store.should_receive(:delete).with(example_bucket)
    Keyspace::Server::Bucket.delete(example_bucket)
  end

  it "stores encrypted data in buckets" do
    ciphertext = writecap.encrypt(example_key, example_value)

    bucket_store.should_receive(:verifycap).and_return(verifycap)
    bucket = Keyspace::Server::Bucket.get(example_bucket)

    # FIXME: BOGUS! Need to implement the real arguments (bucket, key, value)
    bucket_store.should_receive(:put).with(ciphertext)
    bucket.put(ciphertext)
  end
end
