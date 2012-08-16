require 'spec_helper'

describe Vault::Server::Bucket do
  let(:example_bucket) { 'foobar' }
  let(:verifycap) { Vault::Capability.generate(example_bucket).degrade(:v) }
  let(:bucket_store) { mock(:store) }

  it "creates buckets from verifycaps" do
    Vault::Server::Bucket.store = bucket_store
    bucket_store.should_receive(:create).with(verifycap)

    Vault::Server::Bucket.create(verifycap).should be_a Vault::Server::Bucket
  end
end
