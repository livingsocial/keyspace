require 'spec_helper'

describe Vault::Server::App do
  let(:app)          { subject }
  let(:bucket_id)    { 'test_bucket' }
  let(:bucket_store) { mock(:store) }

  it "creates buckets" do
    Vault::Server::Bucket.store = bucket_store

    bucket = Vault::Client::Bucket.create(bucket_id)
    bucket_store.should_receive(:create).with(bucket.verifycap.to_s)

    post "/buckets", :verifycap => bucket.verifycap
    last_response.status.should  == 201
  end
end
