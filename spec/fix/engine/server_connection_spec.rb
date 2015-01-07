require_relative '../../spec_helper'

describe 'FE::ServerConnection' do

  before do
    class SampleServerConnection
      include FE::ServerConnection
    end

    @conn = SampleServerConnection.new
    @conn.comp_id = 'foobar'
  end

  describe '#post_init' do
    it 'should register a client and add a logon timeout' do
      allow(@conn).to receive(:get_peername).and_return('foo')
      expect(Socket).to receive(:unpack_sockaddr_in).once.with('foo').and_return(['some_port', 'some_ip'])
      expect(EM).to receive(:add_timer).once.with(FE::ServerConnection::LOGON_TIMEOUT)
      @conn.post_init
    end
  end

  describe '#logon_timeout' do
    it 'should delete a client and close the connection' do
      expect(FE::Client).to receive(:delete).once
      expect(@conn).to receive(:close_connection_after_writing)
      @conn.logon_timeout
    end
  end

  describe '#unbind' do
    it 'should delete a client' do
      expect(FE::Client).to receive(:delete).once
      @conn.unbind
    end
  end

  describe '#run_message_handler' do

    it 'should log a client in when presented with an initial logon message' do
      @conn.instance_variable_set(:@target_comp_id, nil)

      l = FP::Messages::Logon.new
      l.username        = 'foo'
      l.sender_comp_id  = 'sender'
      l.target_comp_id  = 'foo'
      l.heart_bt_int    = 14

      expect(@conn).to receive(:send_msg) do |msg|
        expect(msg).to be_an_instance_of(FP::Messages::Logon)
        expect(msg.reset_seq_num_flag).to be_truthy
      end

      expect(@conn).to receive(:set_heartbeat_interval).with(14).once
      @conn.run_message_handler(l)
    end

    it 'should accept a second logon message and reset the sequence if requested' do
      @conn.instance_variable_set(:@target_comp_id, nil)
      @conn.instance_variable_set(:@messages, [])

      l = FP::Messages::Logon.new
      l.username            = 'foo'
      l.sender_comp_id      = 'sender'
      l.target_comp_id      = 'foo'
      l.heart_bt_int        = 14
      l.reset_seq_num_flag  = true

      expect(@conn).to receive(:send_msg) do |msg|
        expect(msg).to be_an_instance_of(FP::Messages::Logon)
        expect(msg.reset_seq_num_flag).to be_truthy
      end

      expect(@conn).to receive(:set_heartbeat_interval).with(14).once

      @conn.run_message_handler(l)

      @conn.instance_variable_set(:@send_seq_num, 42)
      expect(@conn.instance_variable_get(:@send_seq_num)).to eql(42)

      @conn.run_message_handler(l)

      expect(@conn.instance_variable_get(:@send_seq_num)).to eql(1)
      expect(@conn.instance_variable_get(:@messages)).to eql([])
    end

    it 'should not expect other messages than a logon if no session is open' do
      mdr = FP::Messages::MarketDataRequest.new
      expect(@conn).to receive(:peer_error).once
      @conn.run_message_handler(mdr)
    end

    it 'should handle a non-logon message when it is received for a valid session' do
      @conn.instance_variable_set(:@target_comp_id, 'foo')
      mdr = FP::Messages::MarketDataRequest.new
      expect(@conn).to receive(:respond_to?).with(:on_market_data_request)
      @conn.run_message_handler(mdr)
    end
  end

end
