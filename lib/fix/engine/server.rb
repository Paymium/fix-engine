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

      REPORT_INTERVAL = 5

      attr_accessor :ip, :port

      def initialize(ip, port)
        @ip   = ip
        @port = port
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
        EM.start_server(ip, port, Connection)
        REPORT_INTERVAL && EM.add_periodic_timer(REPORT_INTERVAL) { report_status }
      end

      def report_status
        log("#{Client.count} client(s) currently connected")
      end

    end
  end
end
