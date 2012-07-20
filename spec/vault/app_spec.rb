require 'spec_helper'
require 'vault/app'

describe Vault::App do
  let(:app)    { subject }
  let(:bucket_id) { 'test_bucket' }

  before do
    FileUtils.rm_rf File.expand_path("../../../buckets/#{bucket_id}", __FILE__)
  end

  it "creates buckets" do
    bucket = Vault::Bucket.create(bucket_id)
    post "/#{bucket.id}", :key => bucket.public_key

    last_response.status.should  == 201
  end
end
