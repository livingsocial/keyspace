require 'spec_helper'

describe Keyspace::Server::Vault do
  let(:example_vault) { 'foobar' }
  let(:example_name)  { 'baz' }
  let(:example_value) { 'quux' }

  let(:writecap)      { Keyspace::Capability.generate(example_vault) }
  let(:verifycap)     { writecap.degrade(:verify) }
  let(:vault_store)   { mock(:store) }

  before :each do
    Keyspace::Server::Vault.store = vault_store
  end

  it "creates vaults from verifycaps" do
    vault_store.should_receive(:create).with(verifycap)
    Keyspace::Server::Vault.create(verifycap).should be_a Keyspace::Server::Vault
  end

  it "deletes vaults" do
    vault_store.should_receive(:delete).with(example_vault)
    Keyspace::Server::Vault.delete(example_vault)
  end

  it "stores encrypted data in vaults" do
    encrypted_message = Keyspace::Message.new(example_name, example_value).encrypt(writecap)
    encrypted_name    = Keyspace::Message.unpack(writecap, encrypted_message)[0]

    vault_store.should_receive(:verifycap).and_return(verifycap)
    vault = Keyspace::Server::Vault.get(example_vault)

    vault_store.should_receive(:put).with(example_vault, encrypted_name, encrypted_message)
    vault.put(encrypted_message)
  end

  it "retrieves encrypted data from vaults" do
    vault_store.should_receive(:verifycap).and_return(verifycap)
    vault = Keyspace::Server::Vault.get(example_vault)

    encrypted_message = Keyspace::Message.new(example_name, example_value).encrypt(writecap)
    vault_store.should_receive(:get).with(example_vault, example_name).and_return encrypted_message
    vault.get(example_name).should == encrypted_message
  end
end
