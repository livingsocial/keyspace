require 'spec_helper'

describe Vault::Server::Bucket do
  let(:example_bucket) { 'foobar' }
  let(:verifycap) { Vault::Capability.generate(example_bucket).degrade(:v) }

  it "creates buckets from verifycaps" do
    Vault::Server::Bucket.create(verifycap).should be_a Vault::Server::Bucket
  end
end
