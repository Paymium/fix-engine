require 'logger'

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
        logger.debug(msg)
      end

      #
      # Returns the current logger
      #
      def self.logger
        @logger ||= ::Logger.new(STDOUT)
      end

    end
  end
end
