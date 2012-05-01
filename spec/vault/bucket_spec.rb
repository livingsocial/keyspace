require 'spec_helper'

describe Vault::Bucket do
  it "creates buckets" do
    with_bucket do |bucket|
      bucket.should be_a Vault::Bucket
    end
  end
  
  def with_bucket(&block)
    bucket = Vault::Bucket.create
    begin
      yield(bucket)
    ensure
      bucket.destroy
    end
  end
end
