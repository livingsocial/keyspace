require 'spec_helper'

describe Vault::Client::Bucket do
  let(:bucket_name)     { 'foobar' }
  let(:example_backend) { MockBackend.new }

  it "creates and persists bucket capabilities" do
    bucket = Vault::Client::Bucket.create(bucket_name)

  end
end
