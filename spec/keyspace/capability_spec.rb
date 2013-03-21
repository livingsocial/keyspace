require 'spec_helper'

describe Keyspace::Capability do
  let(:example_name)  { 'foobar' }
  let(:example_value) { 'X' * 5000 }
  let(:example_date)  { Time.now }

  subject { Keyspace::Capability.generate('test_capability') }

  it "degrades writecaps to readcaps" do
    subject.should be_writecap
    subject.should be_readcap
    subject.should be_verifycap

    readcap = subject.degrade(:read)

    readcap.should_not be_writecap
    readcap.should be_readcap
    readcap.should be_verifycap
  end

  it "degrades writecaps to verifycaps" do
    subject.should be_writecap
    subject.should be_readcap
    subject.should be_verifycap

    verifycap = subject.degrade(:verify)

    verifycap.should_not be_writecap
    verifycap.should_not be_readcap
    verifycap.should be_verifycap
  end
end
