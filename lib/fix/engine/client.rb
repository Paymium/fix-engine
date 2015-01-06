require 'fix/engine/logger'

module Fix
  module Engine

    #
    # Represents a connected client
    #
    class Client

      @clients = {}

      attr_accessor :ip, :port, :connection

      include Logger

      def initialize(ip, port, connection)
        @ip         = ip
        @port       = port
        @connection = connection
       
        self.class.instance_variable_get(:@clients)[key] = self 
      end

      #
      # Returns a client instance from its connection IP
      #
      # @param ip [String] The connection IP
      # @param port [Fixnum] The connection port
      # @param connection [FE::Connection] Optionnally the connection which will used to create an instance if none exists 
      # @return [Fix::Engine::Client] The client connected for this IP
      # 
      def self.get(ip, port, connection = nil)
        @clients[key(ip, port)] || Client.new(ip, port, connection)
      end

      def self.count
        @clients.count
      end

      def self.delete(ip, port)
        @clients.delete(key(ip, port))
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

