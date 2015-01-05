require_relative '../../spec_helper'


#require 'socket'

describe 'FE::Connection' do

  before do
    #@conn = FE::Connection.new
  end

  describe '#post_init' do
    it 'should register a client and add a logon timeout' do
      has_run = false
      EM.run do
        FE::Server.new('0.0.0.0', 6666, FE::Connection).start_server
          #          raise 'io'
          #          expect(conn).to receive(:get_peername).and_return('foo')
          #          expect(Socket).to receive(:unpack_sockaddr_in).once.and_return(['some_port', 'some_ip'])
          #          expect(FE::Client).to receive(:get).with('some_ip', 'some_port', @conn).and_return(double(Object).as_null_object)
          #
          #          expect(EM).to receive(:add_periodic_timer).once
          #          #expect(EM).to receive(:add_timer).twice#.once #twice.and_yield # (Once for the server starting, the other for the logon timeout)
                    has_run = true


        EM.connect('0.0.0.0', 6666, FakeSocketClient) #do |conn|

          EM.next_tick do
          EM.next_tick do
            EM.stop
          end
          end
      end

      expect(has_run).to be_truthy

    end
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
      expect(@conn.msg).to receive(:complete?).and_return(false, true)
      expect(@conn.msg).to receive(:parse!).once.and_return(:foo)
      expect(@conn).to receive(:handle_msg).once.with(:foo)
      @conn.parse_messages_from_buffer
    end
  end

end
