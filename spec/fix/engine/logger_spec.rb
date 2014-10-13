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
    it 'should call debug on a Logger instance' do
      allow(FE::Logger).to receive(:log).and_call_original
      expect_any_instance_of(Logger).to receive(:debug).once.with('foo')
      @o.log('foo')
    end
  end

end


