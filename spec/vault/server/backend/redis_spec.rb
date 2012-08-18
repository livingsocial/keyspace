require 'spec_helper'

describe Vault::Server::Backend::Redis do
  subject { Vault::Server::Backend::Redis.new(::Redis.new(:db => 10))}
  it "creates buckets from verifycaps" do
    subject.create Vault::Capability.generate(:foobar).degrade(:verify)
  end
end