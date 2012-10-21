require 'spec_helper'

describe Keyspace::Server::Backend::Redis do
  subject { Keyspace::Server::Backend::Redis.new(::Redis.new(:db => 10))}

  let(:example_vault)    { :foobar }
  let(:example_key)       { :baz }
  let(:example_value)     { 'quux' }
  let(:example_verifycap) { Keyspace::Capability.generate(example_vault).degrade(:verify) }

  it "creates vaults from verifycaps" do
    subject.create example_verifycap
  end

  it "deletes vaults" do
    subject.create example_verifycap
    expect { subject.delete example_vault }.to_not raise_exception
    expect { subject.delete example_vault }.to raise_exception(Keyspace::VaultNotFoundError)
  end

  it "stores data in vaults" do
    subject.create example_verifycap
    subject.put(example_vault, example_key, example_value)
    subject.get(example_vault, example_key).should == example_value
  end
end
