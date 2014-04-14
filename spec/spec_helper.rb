require 'pry'
require 'simplecov'

SimpleCov.start

require(File.expand_path('../../lib/fix/engine', __FILE__))

RSpec.configure do |config|
  config.mock_with :rspec
end

