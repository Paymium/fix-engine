require_relative '../spec_helper'

describe 'Fix::Engine' do

  describe '.alias_namespace!' do
    it 'should have already been called' do
      expect(FE).to be(Fix::Engine)
    end
  end

  describe '.run!' do
    it 'should create a FE::Server instance and start it' do
      expect(FE::Server).to receive(:new).with('foo', 'bar').once.and_call_original
      expect_any_instance_of(FE::Server).to receive(:run!).once
      FE.run!('foo', 'bar')
    end
  end

end

