require 'spec_helper'

describe Keyspace::Client::Vault do
  let(:vault_name) { 'foobar' }

  it "creates and persists vault capabilities" do
    vault = Keyspace::Client::Vault.create(vault_name)
    
    pending "write a real spec"
  end
end
