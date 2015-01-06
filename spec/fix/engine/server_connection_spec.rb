require_relative '../../spec_helper'

describe 'FE::ServerConnection' do

  before do
    class SampleServerConnection
      include FE::ServerConnection
    end

    @conn = SampleServerConnection.new
  end

  describe '#post_init' do
    it 'should register a client and add a logon timeout' do
      allow(@conn).to receive(:get_peername).and_return('foo')
      expect(Socket).to receive(:unpack_sockaddr_in).once.with('foo').and_return(['some_port', 'some_ip'])
      expect(FE::Client).to receive(:get).with('some_ip', 'some_port', @conn).and_return(double(Object).as_null_object)
      expect(EM).to receive(:add_timer).once.with(FE::ServerConnection::LOGON_TIMEOUT)
      @conn.post_init
    end
  end

end
