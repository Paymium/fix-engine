require_relative '../spec_helper'

describe 'Fix::Engine' do

  describe '.alias_namespace!' do
    it 'should have already been called' do
      FE.should be(Fix::Engine)
    end
  end

  describe '.run!' do
    it 'should create a FE::Server instance and start it' do
      FE::Server.should_receive(:new).with('foo', 'bar').once.and_call_original
      FE::Server.any_instance.should_receive(:run!).once
      FE.run!('foo', 'bar')
    end
  end

end

