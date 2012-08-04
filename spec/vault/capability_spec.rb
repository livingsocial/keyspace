require 'spec_helper'

describe Vault::Capability do
  let(:example_key)   { 'foobar' }
  let(:example_value) { 'X' * 5000 }
  let(:example_date)  { Time.now }

  subject { Vault::Capability.generate('test_capability') }

  it "encrypts and decrypts values for storage in a capability" do
    encrypted_value  = subject.encrypt(example_key, example_value, example_date)
    key, value, date = subject.decrypt(encrypted_value)

    key.should   eq example_key
    value.should eq example_value
    date.utc.to_i.should eq example_date.utc.to_i
  end
end
