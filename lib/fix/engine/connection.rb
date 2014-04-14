require 'eventmachine'

module Fix
  module Engine
    class Connection < EM::Connection

      include Logger

      attr_accessor :ip, :port, :client

      def post_init
        @port, @ip  = Socket.unpack_sockaddr_in(get_peername)
        @client     = Client.get(ip)
        @message    = nil
      end

      def receive_data(data)
        log("Receive data <#{data}>")
        @message_buffer << data.chomp
        parse_messages_from_buffer
      end

      def parse_messages_from_buffer
        while idx = @message_buffer.index(SEPARATOR)
          field = @message_buffer.slice!(0, idx + 1).gsub(/#{SEPARATOR}\Z/, '')

          @message.append(field)

          if @message.complete?
            @message.handle
            @message = Message.new
          end
        end
      end

    end
  end
end

