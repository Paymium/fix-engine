require 'eventmachine'

module Fix
  module Engine
    class Connection < EM::Connection

      include Logger

      attr_accessor :ip, :port, :client

      def post_init
        @port, @ip  = Socket.unpack_sockaddr_in(get_peername)
        @client     = Client.get(ip)
        @msg_buf    = ""
        @msg        = Message.new

        log("Client connected from <#{ip}:#{port}>")
      end

      def receive_data(data)
        @msg_buf << data.chomp
        parse_msgs_from_buf
      end

      def parse_messages_from_buffer
        while idx = @msg_buf.index(SEPARATOR)
          field = @msg_buf.slice!(0, idx + 1).gsub(/#{SEPARATOR}\Z/, '')

          @msg.append(field)

          if @msg.complete?
            log("Received message <#{data}>")
            @msg.handle
            @msg = Message.new
          end
        end
      end

    end
  end
end

