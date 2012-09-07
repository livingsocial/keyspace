require 'spec_helper'

describe Keyspace::Server::App do
  let(:app)            { subject }
  let(:bucket_store)   { mock(:store) }

  let(:example_bucket) { 'foobar' }
  let(:example_key)    { 'baz' }
  let(:example_value)  { 'quux' }

  let(:writecap)       { Keyspace::Capability.generate(example_bucket) }
  let(:readcap)        { writecap.degrade(:read) }
  let(:verifycap)      { writecap.degrade(:verify) }

  before :each do
    Keyspace::Server::Bucket.store = bucket_store
  end

  it "creates buckets" do
    bucket = Keyspace::Client::Bucket.create(example_bucket)
    bucket_store.should_receive(:create).with(bucket.verifycap.to_s)

    post "/buckets", :verifycap => bucket.verifycap
    last_response.status.should == 201
  end

  it "stores data in buckets" do
    ciphertext = writecap.encrypt(example_key, example_value)
    bucket_store.should_receive(:verifycap).with(example_bucket).and_return(verifycap.to_s)

    bucket_store.should_receive(:put).with(example_bucket, example_key, ciphertext)

    put "/buckets/#{example_bucket}", ciphertext, "CONTENT_TYPE" => Keyspace::MIME_TYPE
    last_response.status.should == 200
  end

  it "retrieves data from buckets" do
    bucket_store.should_receive(:verifycap).with(example_bucket).and_return(verifycap.to_s)

    ciphertext = writecap.encrypt(example_key, example_value)
    bucket_store.should_receive(:get).with(example_bucket, example_key).and_return ciphertext
    get "/buckets/#{example_bucket}/#{example_key}"

    last_response.status.should == 200
    key, value, _ = readcap.decrypt(last_response.body)

    key.should eq example_key
    value.should eq example_value
  end
end
