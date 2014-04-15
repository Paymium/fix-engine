require_relative '../../spec_helper'

describe 'FE::Connection' do

  before do
    @conn = Object.new
    @conn.instance_eval do
      class << self
        include FE::Connection
      end
    end
  end

  describe '#post_init' do
    it 'should register a client' do
      @conn.stub(:get_peername).and_return('foo')
      Socket.should_receive(:unpack_sockaddr_in).once.with('foo').and_return(['some_port', 'some_ip'])
      FE::Client.should_receive(:get).with('some_ip')
      @conn.post_init
    end
  end

  describe '#receive_data' do
    it 'should buffer data and parse the buffer' do
      @conn.msg_buf.should_receive(:<<).with('some_data')
      @conn.should_receive(:parse_messages_from_buffer).once
      @conn.receive_data('some_data')
    end
  end

  describe '#parse_messages_from_buffer' do
    it 'should append fields to the FE::Message instance' do
      @conn.msg_buf << "69=DATA\x0170=OTHER_DATA\x0171=SOME_INCOMPLETE_DATA"
      @conn.parse_messages_from_buffer
      @conn.msg.fields.should eql([[69, 'DATA'], [70, 'OTHER_DATA']])
      @conn.msg_buf.should eql('71=SOME_INCOMPLETE_DATA')
    end

    it 'should handle a message if it is complete' do
      @conn.msg_buf << "69=DATA\x01"
      @conn.msg.should_receive(:complete?).once.and_return(false, true)
      @conn.msg.should_receive(:handle).once
      @conn.parse_messages_from_buffer
    end
  end

end
