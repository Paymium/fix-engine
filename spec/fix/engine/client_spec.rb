require_relative '../../spec_helper'

require 'fix/engine/client'

describe 'FE::Client' do

  before do
    @client = FE::Client.new('127.0.0.1', 6464, Object.new)
  end

  describe '.get' do
    it 'should instantiate a new client if there is none registered with the same IP' do
      expect(FE::Client).to receive(:new).with('ip', 'port', 'connection').and_call_original
      expect(FE::Client.get('ip', 'port', 'connection')).to be_a_kind_of(FE::Client)
    end

    it 'should return the correct client' do
      expect(FE::Client.get('127.0.0.1', 6464)).to be(@client)
    end
  end

  describe '.count' do
    it 'should be incremented for each new client' do
      expect { FE::Client.new('1.2.3.4', 9922, nil) }.to change { FE::Client.count }.by(1)
    end
  end

  describe '.delete' do
    it 'should decrease the count by one' do
      FE::Client.new('1.2.3.4', 6289, nil)
      expect { FE::Client.delete('1.2.3.4', 6289) }.to change { FE::Client.count }.by(-1)
    end
  end

end
