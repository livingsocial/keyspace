require 'spec_helper'

describe Vault::Server::App do
  let(:app)            { subject }
  let(:example_bucket) { 'foobar' }
  let(:example_key)    { 'baz' }
  let(:example_value)  { 'quux' }
  let(:bucket_store)   { mock(:store) }
  let(:writecap)       { Vault::Capability.generate(example_bucket) }
  let(:verifycap)      { writecap.degrade(:verify) }

  before :each do
    Vault::Server::Bucket.store = bucket_store
  end

  it "creates buckets" do
    bucket = Vault::Client::Bucket.create(example_bucket)
    bucket_store.should_receive(:create).with(bucket.verifycap.to_s)

    post "/buckets", :verifycap => bucket.verifycap
    last_response.status.should == 201
  end

  it "stores data in buckets" do
    ciphertext = writecap.encrypt(example_key, example_value)
    bucket_store.should_receive(:verifycap).and_return(verifycap.to_s)

    # FIXME: BOGUS! Need to implement the real arguments (bucket, key, value)
    bucket_store.should_receive(:put).with(ciphertext)

    put "/buckets/#{example_bucket}", ciphertext, "CONTENT_TYPE" => "application/octet-stream"
    last_response.status.should == 200
  end
end
