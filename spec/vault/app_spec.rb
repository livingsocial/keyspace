require 'spec_helper'
require 'vault/app'

describe Vault::App do
  let(:app) { subject }

  it "creates buckets" do
    bucket = Vault::Bucket.create
    post "/#{bucket.id}", :key => bucket.verify_key.to_der
    last_response.status.should == 201
  end
end
