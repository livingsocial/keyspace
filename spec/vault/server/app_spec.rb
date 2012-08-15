require 'spec_helper'

describe Vault::Server::App do
  let(:app)    { subject }
  let(:bucket_id) { 'test_bucket' }

  before do
    FileUtils.rm_rf File.expand_path("../../../buckets/#{bucket_id}", __FILE__)
  end

  it "creates buckets" do
    bucket = Vault::Client::Bucket.create(bucket_id)
    post "/buckets", :verifycap => bucket.verifycap

    last_response.status.should  == 201
  end
end
