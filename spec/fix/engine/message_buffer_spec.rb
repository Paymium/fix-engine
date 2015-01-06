require_relative '../../spec_helper'

require 'fix/engine/message_buffer'

describe 'FE::MessageBuffer' do

  before do
    @msg = FE::MessageBuffer.new { |m| }
  end

  describe '#append' do
    it 'should add a field to the field collection' do
      @msg.append("69=SEX\x01")
      expect(@msg.fields).to eql([[69, 'SEX']])
    end

    it 'should explode if appending to a completed message' do
      expect(@msg).to receive(:complete?).once.and_return(true)
      expect { @msg.append("69=SEX\x01") }.to raise_error
    end
  end

  describe '#complete?' do
    it 'should consider a message complete when the last field is a checksum field' do
      @msg.append("10=123\x01")
      expect(@msg.complete?).to be_truthy
    end

    it 'should not consider a message complete without a terminating checksum field' do
      @msg.append("68=123\x01")
      expect(@msg.complete?).to be_falsey
    end
  end

  describe '#debug' do
    it 'should output the message in a readable format' do
      @msg.add_data("69=DATA\x0170=OTHER_DATA\x0171=SOME_INCOMPLETE_DATA")
      expect(@msg.debug).to eql("69=DATA|70=OTHER_DATA|71=SOME_INCOMPLETE_DATA")
    end
  end

  describe '#parse_messages' do
    it 'should append fields to the FE::Message instance' do
      @msg.add_data("69=DATA\x0170=OTHER_DATA\x0171=SOME_INCOMPLETE_DATA")
      @msg.parse_messages
      expect(@msg.fields).to eql([[69, 'DATA'], [70, 'OTHER_DATA']])
      expect(@msg.msg_buf).to eql('71=SOME_INCOMPLETE_DATA')
    end

    it 'should handle a message if it is complete' do
      parsed = Object.new

      @mb = FE::MessageBuffer.new do |m|
        expect(m).to be(parsed)
      end

      @mb.msg_buf << "69=DATA\x01"
      expect(@mb).to receive(:complete?).and_return(false, true)
      expect(FP).to receive(:parse).once.and_return(parsed)
      @mb.parse_messages
    end
  end

end

