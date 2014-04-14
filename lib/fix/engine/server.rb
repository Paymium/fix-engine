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

      def initialize(ip = '127.0.0.1', port = 8359)
        @ip   = ip
        @port = port
      end

      #
      # Starts running the server engine
      #
      def run
        trap('INT') do
          EM.stop
        end

        EM.run do
          EM.start_server(host, port, Connection)
        end
      end

    end
  end
end
