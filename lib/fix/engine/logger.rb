require 'em-logger'

module Fix
  module Engine

    #
    # Naive logger implementation used in development
    #
    module Logger

      @@logger = nil

      #
      # Logs a message to the standard output
      #
      # @param msg [String] The message to log
      #
      def log(msg)
        FE::Logger.log(msg)
      end

      #
      # Class-methods are easier to stub to disable logging while
      # running specs
      #
      def self.log(msg)
        @logger ||= EM::Logger.new(::Logger.new(STDOUT))
        @logger.debug(msg)
      end

    end
  end
end
