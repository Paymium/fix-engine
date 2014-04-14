require_relative '../../spec_helper'

describe 'FE::Logger' do

  before do
    @o = Object.new
    @o.instance_eval do
      class << self
        include FE::Logger
      end
    end
  end

  describe '.log' do
    it 'should call puts' do
      @o.should_receive(:puts).with('foo').once
      @o.log('foo')
    end
  end

end


