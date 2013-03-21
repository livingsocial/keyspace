require 'spec_helper'

describe Keyspace::Message do
  let(:example_name)  { 'foobar' }
  let(:example_value) { 'X' * 5000 }
  let(:example_date)  { Time.now }
  let(:capability)    { Keyspace::Capability.generate('test_capability') }

  subject { described_class.new(example_name, example_value, example_date) }

  it "encrypts and decrypts values for storage in a capability" do
    encrypted_message = subject.encrypt(capability)
    message           = described_class.decrypt(capability, encrypted_message)

    message.name.should  eq example_name
    message.value.should eq example_value
    message.timestamp.to_i.should eq example_date.to_i
  end
end
