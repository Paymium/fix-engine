require_relative '../../spec_helper'

describe 'FE::ClientConnection' do

  before do
    class SampleClientConnection
      include FE::ClientConnection
    end

    @conn = SampleClientConnection.new
  end

  describe '#post_init' do
    it 'should logon' do
      expect(EM).to receive(:next_tick).and_yield
      expect(@conn).to receive(:send_msg) do |*args|
        expect(args.first).to be_an_instance_of(FP::Messages::Logon)
      end

      @conn.post_init
    end
  end

  describe '#on_logon' do
    it 'should consider us logged-in' do
      @conn.on_logon(FP::Messages::Logon.new)
      expect(@conn.instance_variable_get(:@logged_in)).to be_truthy
    end
  end

end

