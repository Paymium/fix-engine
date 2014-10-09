require 'fix/engine/logger'

module Fix
  module Engine

    #
    # Represents a connected client
    #
    class Client

      @@clients = {}

      attr_accessor :ip, :port, :connection, :client_id

      include Logger

      def initialize(ip, port, connection)
        @ip         = ip
        @port       = port
        @connection = connection
      end

      #
      # Returns a client instance from its connection IP
      #
      # @param ip [String] The connection IP
      # @return [Fix::Engine::Client] The client connected for this IP
      # 
      def self.get(ip, port, connection)
        @@clients[key(ip, port)] ||= Client.new(ip, port, connection)
      end

      def self.count
        @@clients.count
      end

      def self.delete(ip, port)
        @@clients.delete(key(ip, port))
      end

      def has_session?
        !!client_id
      end

      def key
        self.class.key(ip, port)
      end

      def self.key(ip, port)
        "#{ip}:#{port}"
      end

    end
  end
end

