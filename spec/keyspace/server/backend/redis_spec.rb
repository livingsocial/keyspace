require 'spec_helper'

describe Keyspace::Server::Backend::Redis do
  subject { Keyspace::Server::Backend::Redis.new(::Redis.new(:db => 10))}

  let(:example_bucket)    { :foobar }
  let(:example_key)       { :baz }
  let(:example_value)     { 'quux' }
  let(:example_verifycap) { Keyspace::Capability.generate(example_bucket).degrade(:verify) }

  it "creates buckets from verifycaps" do
    subject.create example_verifycap
  end

  it "deletes buckets" do
    subject.create example_verifycap
    expect { subject.delete example_bucket }.to_not raise_exception
    expect { subject.delete example_bucket }.to raise_exception(Keyspace::BucketNotFoundError)
  end

  it "stores data in buckets" do
    subject.create example_verifycap
    subject.put(example_bucket, example_key, example_value)
    subject.get(example_bucket, example_key).should == example_value
  end
end
