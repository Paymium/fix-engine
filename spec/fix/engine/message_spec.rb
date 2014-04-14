require_relative '../../spec_helper'

require 'fix/engine/message'

describe 'FE::Message' do

  before do
    @msg = FE::Message.new
  end

  describe '#append' do
    it 'should add a field to the field collection' do
      @msg.append("69=SEX\x01")
      @msg.fields.should eql([[69, 'SEX']])
    end

    it 'should explode if appending to a completed message' do
      @msg.should_receive(:complete?).once.and_return(true)
      expect { @msg.append("69=SEX\x01") }.to raise_error
    end
  end

  describe '#complete?' do
    it 'should consider a message complete when the last field is a checksum field' do
      @msg.append("10=123\x01")
      @msg.complete?.should be_true
    end

    it 'should not consider a message complete without a terminating checksum field' do
      @msg.append("68=123\x01")
      @msg.complete?.should be_false
    end
  end

end

