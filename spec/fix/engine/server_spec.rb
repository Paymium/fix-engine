require_relative '../../spec_helper'

describe 'FE::Server' do

  before do
    @server = FE::Server.new('1.2.3.4', 1234)
  end

  describe '#run!' do
    it 'should start a server in an event loop' do
      EM.should_receive(:run).once
      @server.run!
    end
  end

  describe '#start_server' do
    it 'should raise an error if no reactor is running' do
      expect { @server.start_server }.to raise_error
    end

    it 'should start a listener if a reactor is running' do
      EM.should_receive(:reactor_running?).once.and_return(true)
      EM.should_receive(:start_server).once.with('1.2.3.4', 1234, FE::Connection)
      @server.start_server
    end
  end

end

