module Fix
  module Engine

    #
    # Naive logger implementation used in development
    #
    module Logger

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
        puts(msg)
      end

    end
  end
end
