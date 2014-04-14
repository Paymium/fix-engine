require 'fix/engine/logger'
require 'fix/engine/server'

#
# Main FIX namespace
#
module Fix

  #
  # Main Fix::Engine namespace
  #
  module Engine

    #
    # Runs a FIX server engine
    #
    def self.run
      Server.run
    end

    #
    # Alias the +Fix::Engine+ namespace to +FE+ if possible, because lazy is not necessarily dirty
    #
    def self.alias_namespace!
      Object.const_set(:FE, Engine) unless Object.const_defined?(:FE)
    end

  end
end

Fix::Engine.alias_namespace!

