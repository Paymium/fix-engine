require 'eventmachine'
require 'fix/protocol'
require 'fix/engine/connection'

module Fix
  module Engine

    #
    # Main FIX engine server class
    #
    class Server

      include Logger

      attr_accessor :ip, :port

      def initialize(ip, port)
        @ip   = ip
        @port = port

        run!
      end

      #
      # Starts running the server engine
      #
      def run!
        trap('INT') { EM.stop }

        EM.run do
          EM.start_server(ip, port, Connection)
        end
      end

    end
  end
end
