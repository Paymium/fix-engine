module Fix
  module Engine
    module Logger

      #
      # Logs a message to the standard output
      #
      # @param msg [String] The message to log
      #
      def log(msg)
        puts(msg)
      end

    end
  end
end
