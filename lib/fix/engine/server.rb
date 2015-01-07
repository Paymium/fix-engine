require 'eventmachine'

require 'fix/protocol'
require 'fix/engine/version'
require 'fix/engine/server_connection'

module Fix
  module Engine

    #
    # Main FIX engine server class
    #
    class Server

      include Logger

      #
      # Periodicity in seconds of logged status reports
      #
      REPORT_INTERVAL = 10

      attr_accessor :ip, :port

      def initialize(ip, port, handler, &block)
        @ip       = ip
        @port     = port
        @handler  = handler
        @block    = block
      end

      #
      # Starts running the server engine
      #
      def run!
        trap('INT') { EM.stop }
        log("Starting FIX engine v#{FE::VERSION}, listening on <#{ip}:#{port}>, exit with <Ctrl-C>")
        EM.run { start_server }
      end

      #
      # Starts a listener inside a running reactor
      #
      def start_server
        raise "EventMachine must be running to start a server" unless EM.reactor_running?

        EM.start_server(ip, port, @handler) { |conn| @block && @block.call(conn) }

        REPORT_INTERVAL && EM.add_periodic_timer(REPORT_INTERVAL) { report_status }
      end

      #
      # Logs a short summary of the current server status
      #
      def report_status
        log("#{Client.count} client(s) currently connected")
      end

    end
  end
end
