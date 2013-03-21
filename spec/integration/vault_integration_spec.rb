require 'spec_helper'

describe "Vault integration" do
  let(:example_port)  { 12345 }
  let(:example_url)   { "http://127.0.0.1:#{example_port}/" }

  let(:example_vault) { "foobar" }
  let(:example_name)  { "qux" }
  let(:example_value) { "This is an example value" }

  before :all do
    Keyspace::Server::Vault.store = Moneta.new(:Redis)

    Keyspace::Server::App.set(:port, example_port)
    @thread = Thread.new { Keyspace::Server::App.run! }
    sleep 0.5 # hax!
    Thread.pass until @thread.status && @thread.status == "sleep"

    Keyspace::Client.url = example_url
  end

  before :each do
    # Ensure there's no vault left over in Redis
    begin
      Keyspace::Server::Vault.delete(example_vault)
    rescue Keyspace::VaultNotFoundError
    end
  end

  after :all do
    @thread.kill
  end

  it "creates vaults" do
    Keyspace::Client::Vault.create(example_vault).save
    Keyspace::Server::Vault.get(example_vault).should be_a Keyspace::Server::Vault
  end

  it "stores data in vaults" do
    vault = Keyspace::Client::Vault.create(example_vault)
    vault.save!

    vault[:foo] = example_value
    vault.save!

    vault[:foo].should eq example_value
  end
  
  it "deletes vaults" do
    vault = Keyspace::Client::Vault.create(example_vault)
    vault.save!
    
    vault.delete
    vault.save!
  end
end
