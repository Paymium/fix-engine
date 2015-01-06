require_relative '../../spec_helper'


#require 'socket'

describe 'FE::Connection' do

  before do
    class SampleConnection
      include FE::Connection
    end

    @conn = SampleConnection.new
    @conn.target_comp_id = 'PEER'
    @conn.comp_id = 'ME'

    @conn.post_init
  end

  describe '#receive_data' do
    it 'should buffer data' do
      expect_any_instance_of(FE::MessageBuffer).to receive(:add_data).with('some_data')
      @conn.receive_data('some_data')
    end
  end

  describe '#send_heartbeat' do
    it 'should send a heartbeat' do
      expect(@conn).to receive(:send_data) do |data|
        expect(FP.parse(data).test_req_id).to eql('badum')
      end

      @conn.send_heartbeat('badum')
    end
  end

  describe '#set_heartbeat interval' do
    it 'should add a periodic timer' do
      expect(EM).to receive(:add_periodic_timer).once
      @conn.set_heartbeat_interval(1)
    end
  end

  describe '#keep_alive' do
    before do
      allow(EM).to receive(:add_periodic_timer)
      @conn.set_heartbeat_interval(1)
    end

    it 'should send a heartbeat if necessary' do
      expect(@conn).to receive(:send_heartbeat).once
      expect(@conn).to receive(:send_test_request).once
      @conn.keep_alive
    end

    it 'should not send a heartbeat if not necessary' do
      expect(@conn).to receive(:send_heartbeat).never
      expect(Time).to receive(:now).and_return(0, 0)
      @conn.keep_alive
    end
  end

  describe '#send_test_request' do
    it 'should send a test request' do
      expect(@conn).to receive(:send_msg) do |d|
        expect(d).to be_an_instance_of(FP::Messages::TestRequest)
      end

      # When we have a test request pending, and the timeout fires
      expect(@conn).to receive(:kill!).once
      expect(EM).to receive(:add_timer).and_yield

      @conn.send_test_request
    end
  end

  describe '#send_msg' do
    it 'should raise when attempting to send an invalid message' do
      expect { @conn.send_msg(FP::Messages::Logon.new) }.to raise_error
    end
  end

  describe '#peer_error' do
    it 'should issue a reject and kill the connection' do
      expect(@conn).to receive(:close_connection_after_writing)
      expect(@conn).to receive(:send_msg).twice # one for the reject, one for the logout
      @conn.peer_error('foo', 1)
    end
  end

  describe '#unbind' do
    it 'should cancel the keepalive timer' do
      timer = Object.new
      @conn.instance_variable_set(:@keep_alive_timer, timer)
      expect(timer).to receive(:cancel)
      @conn.unbind
    end
  end

  describe '#run_message_handler' do
    it 'should call the relevant method' do
      class Foo; end
      @conn.instance_eval do
        class << self
          def on_foo(msg)
          end
        end
      end

      foo_msg = Foo.new
      expect(@conn).to receive(:on_foo).once.with(foo_msg)
      @conn.run_message_handler(foo_msg)
    end
  end

  describe '#receive_data' do
    it 'should process a valid message' do
      msg = FP::Messages::Heartbeat.new
      msg.sender_comp_id  = 'FOO'
      msg.target_comp_id  = 'BAR'
      msg.msg_seq_num     = 1

      expect(@conn).to receive(:process_msg).once
      @conn.receive_data(msg.dump)
    end

    it 'should notify parse failures' do
      expect_any_instance_of(FE::MessageBuffer).to receive(:add_data).with('foo')
      expect(@conn).to receive(:peer_error)
      expect(FE::MessageBuffer).to receive(:new).and_yield(FP::ParseFailure.new(nil)).and_return(FE::MessageBuffer.new { |p| })
      @conn.receive_data('foo')
    end

    it 'should kill the connection when an exception is raised' do
      expect_any_instance_of(FE::MessageBuffer).to receive(:add_data).with('foo') do
        raise 'error'
      end

      expect(@conn).to receive(:kill!).once
      @conn.receive_data('foo')
    end
  end

  describe '#process_msg' do

    it 'should respond to resend requests' do
      rr = FP::Messages::ResendRequest.new
      rr.msg_seq_num = 1
      rr.begin_seq_no = 1
      rr.end_seq_no = 1
      rr.target_comp_id = 'ME'
      rr.sender_comp_id = 'PEER'

      @conn.instance_variable_get(:@messages) << rr

      expect(@conn).to receive(:send_data).with(rr.dump)
      @conn.receive_data(rr.dump)
    end

    it 'should keep track of pending test requests' do
      hb = FP::Messages::Heartbeat.new
      hb.msg_seq_num = 1
      hb.test_req_id = 'x'
      hb.target_comp_id = 'ME'
      hb.sender_comp_id = 'PEER'

      @conn.instance_variable_set(:@pending_test_req_id, 'x')
      @conn.process_msg(hb)
      expect(@conn.instance_variable_get(:@pending_test_req_id)).to be_nil
    end

    it 'should respond to test requests' do
      tr = FP::Messages::TestRequest.new
      tr.msg_seq_num = 1
      tr.test_req_id = 'x'
      tr.target_comp_id = 'ME'
      tr.sender_comp_id = 'PEER'

      expect(@conn).to receive(:send_msg) do |msg|
        expect(msg).to be_an_instance_of(FP::Messages::Heartbeat)
      end

      @conn.process_msg(tr)
    end

    it 'should delegate the processing to the correct message handler' do
      mdr = FP::Messages::MarketDataRequest.new
      mdr.sender_comp_id  = 'PEER'
      mdr.target_comp_id  = 'ME'
      mdr.msg_seq_num     = 1  

      expect(@conn).to receive(:run_message_handler).with(mdr)
      @conn.process_msg(mdr)
    end

    it 'should ignore stale messages' do
      mdr = FP::Messages::MarketDataRequest.new
      mdr.sender_comp_id  = 'PEER'
      mdr.target_comp_id  = 'ME'
      mdr.msg_seq_num     = 0

      expect(@conn).to receive(:run_message_handler).never
      @conn.process_msg(mdr)
    end

    it 'should request a resend if relevant' do
      mdr = FP::Messages::MarketDataRequest.new
      mdr.sender_comp_id  = 'PEER'
      mdr.target_comp_id  = 'ME'
      mdr.msg_seq_num     = 10

      expect(@conn).to receive(:send_msg) do |m|
        expect(m).to be_an_instance_of(FP::Messages::ResendRequest)
        expect(m.begin_seq_no).to be(1)
        expect(m.end_seq_no).to be(0)
      end

      @conn.process_msg(mdr)
    end

    it 'should fail to process for an incorrect target comp id' do
      mdr = FP::Messages::MarketDataRequest.new
      mdr.sender_comp_id  = 'PEER'
      mdr.target_comp_id  = 'FAIL'
      mdr.msg_seq_num     = 1

      expect(@conn).to receive(:peer_error).once
      @conn.process_msg(mdr)
    end
  end

end

