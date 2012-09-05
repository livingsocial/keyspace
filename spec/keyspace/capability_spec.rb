require 'spec_helper'

describe Keyspace::Capability do
  let(:example_key)   { 'foobar' }
  let(:example_value) { 'X' * 5000 }
  let(:example_date)  { Time.now }

  subject { Keyspace::Capability.generate('test_capability') }

  it "encrypts and decrypts values for storage in a capability" do
    encrypted_value  = subject.encrypt(example_key, example_value, example_date)
    key, value, date = subject.decrypt(encrypted_value)

    key.should   eq example_key
    value.should eq example_value
    date.utc.to_i.should eq example_date.utc.to_i
  end

  it "degrades writecaps to verifycaps" do
    subject.should be_writecap
    subject.should be_readcap
    subject.should_not be_verifycap

    verifycap = subject.degrade(:verify)

    verifycap.should_not be_writecap
    verifycap.should_not be_readcap
    verifycap.should be_verifycap
  end
end
