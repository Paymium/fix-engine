require_relative '../../spec_helper'

require 'fix/engine/client'

describe 'FE::Client' do

  describe '.get' do
    it 'should instantiate a new client if there is none registered with the same IP' do
      expect(FE::Client).to receive(:new).with('ip', 'port', 'connection').and_call_original
      expect(FE::Client.get('ip', 'port', 'connection')).to be_a_kind_of(FE::Client)
    end
  end

end

