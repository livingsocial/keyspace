require 'spec_helper'

describe Vault::Server::Backend::Redis do
  subject { Vault::Server::Backend::Redis.new(::Redis.new(:db => 10))}

  let(:example_bucket)    { :foobar }
  let(:example_key)       { :baz }
  let(:example_value)     { 'quux' }
  let(:example_verifycap) { Vault::Capability.generate(example_bucket).degrade(:verify) }

  it "creates buckets from verifycaps" do
    subject.create example_verifycap
  end

  it "deletes buckets" do
    subject.create example_verifycap
    expect { subject.delete example_bucket }.to_not raise_exception
    expect { subject.delete example_bucket }.to raise_exception(Vault::BucketNotFoundError)
  end

  it "stores data in buckets" do
    subject.create example_verifycap
    subject.put(example_bucket, example_key, example_value)
    subject.get(example_bucket, example_key).should == example_value
  end
end
