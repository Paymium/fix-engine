require 'simplecov'
require 'coveralls'

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]
SimpleCov.start

require(File.expand_path('../../lib/fix/engine', __FILE__))

RSpec.configure do |config|
  config.mock_with :rspec

  config.before(:each) do
    allow(FE::Logger).to receive(:log)
  end
end

