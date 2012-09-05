require 'spec_helper'

describe Keyspace::Client::Bucket do
  let(:bucket_name) { 'foobar' }

  it "creates and persists bucket capabilities" do
    bucket = Keyspace::Client::Bucket.create(bucket_name)

  end
end
