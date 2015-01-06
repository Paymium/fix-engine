require_relative '../../spec_helper'


#require 'socket'

describe 'FE::Connection' do

  before do
    class SampleConnection
      include FE::ClientConnection
    end

    @conn = SampleConnection.new
  end

  describe '#receive_data' do
    it 'should buffer data and parse the buffer' do
      expect(@conn.msg_buf).to receive(:<<).with('some_data')
      expect(@conn).to receive(:parse_messages_from_buffer).once
      @conn.receive_data('some_data')
    end
  end

  describe '#parse_messages_from_buffer' do
    it 'should append fields to the FE::Message instance' do
      @conn.msg_buf << "69=DATA\x0170=OTHER_DATA\x0171=SOME_INCOMPLETE_DATA"
      @conn.parse_messages_from_buffer
      expect(@conn.msg.fields).to eql([[69, 'DATA'], [70, 'OTHER_DATA']])
      expect(@conn.msg_buf).to eql('71=SOME_INCOMPLETE_DATA')
    end

    it 'should handle a message if it is complete' do
      @conn.msg_buf << "69=DATA\x01"
      parsed = Object.new
      expect(@conn.msg).to receive(:complete?).and_return(false, true)
      expect(@conn.msg).to receive(:parse!).once.and_return(parsed)
      expect(@conn).to receive(:process_msg).once.with(parsed)
      expect(parsed).to receive(:is_a?).with(FP::Message).once.and_return(true)
      @conn.parse_messages_from_buffer
    end
  end

end


