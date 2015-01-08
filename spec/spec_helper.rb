require 'simplecov'

SimpleCov.start

require(File.expand_path('../../lib/fix/engine', __FILE__))

RSpec.configure do |config|
  config.mock_with :rspec

  config.before(:each) do
    allow(FE::Logger).to receive(:log)
  end
end

class FakeSocketClient < EM::Connection
def post_init
  send_data('io')
end
end
