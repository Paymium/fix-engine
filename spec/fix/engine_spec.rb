require_relative '../spec_helper'

describe 'Fix::Engine' do

  describe '.alias_namespace!' do
    it 'should have already been called' do
      FE.should be(Fix::Engine)
    end
  end

end

