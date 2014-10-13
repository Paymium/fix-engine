require_relative '../../spec_helper'

describe 'FE::Server' do

  before do
    @server = FE::Server.new('1.2.3.4', 1234, FE::Connection)
  end

  describe '#run!' do
    it 'should start a server in an event loop' do
      expect(EM).to receive(:run).once
      @server.run!
    end
  end

  describe '#start_server' do
    it 'should raise an error if no reactor is running' do
      expect { @server.start_server }.to raise_error
    end

    it 'should start a listener if a reactor is running' do
      allow(EM).to receive(:add_periodic_timer)
      expect(EM).to receive(:reactor_running?).once.and_return(true)
      expect(EM).to receive(:start_server).once.with('1.2.3.4', 1234, FE::Connection)
      @server.start_server
    end
  end

end

