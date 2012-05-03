require 'spec_helper'

describe Vault::Bucket do
  let(:example_key)   { 'foobar' }
  let(:example_value) { 'X' * 5000 }
  let(:example_date)  { Time.now }

  it "creates buckets" do
    with_bucket do |bucket|
      bucket.should be_a Vault::Bucket
    end
  end

  it "encrypts and decrypts values for storage in a bucket" do
    with_bucket do |bucket|
      encrypted_value = bucket.encrypt(example_key, example_value, example_date)
      key, value, date = bucket.decrypt(encrypted_value)

      key.should   eq example_key
      value.should eq example_value
      date.utc.to_i.should eq example_date.utc.to_i
    end
  end

  def with_bucket(&block)
    bucket = Vault::Bucket.create
    bucket.save

    begin
      yield(bucket)
    ensure
      bucket.destroy
    end
  end
end
