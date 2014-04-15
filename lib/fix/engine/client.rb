module Fix
  module Engine

    #
    # Represents a connected client
    #
    class Client

      @@clients = {}

      attr_accessor :ip, :data_connection, :trading_connection

      def initialize(ip)
        @ip = ip
      end

      #
      # Returns a client instance from its connection IP
      #
      # @param ip [String] The connection IP
      # @return [Fix::Engine::Client] The client connected for this IP
      #
      def self.get(ip)
        @@clients[ip] ||= Client.new(ip)
      end

    end
  end
end

