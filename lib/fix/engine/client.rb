module Fix
  module Engine
    class Client

      @@clients = {}

      attr_accessor :ip, :data_connection, :trading_connection

      def self.get(ip)
        @@clients[ip] ||= Client.new(ip)
      end

      def initialize(ip)
        @ip = ip
      end

    end
  end
end

