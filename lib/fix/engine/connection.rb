require 'eventmachine'

require 'fix/engine/message_buffer'
require 'fix/engine/client'

module Fix
  module Engine

    #
    # The client connection handling logic and method overrides
    #
    module Connection

      include Logger

      attr_accessor :ip, :port, :client, :msg_buf

      #
      # Run after a client has connected
      #
      def post_init
        @port, @ip  = Socket.unpack_sockaddr_in(get_peername)
        @client     = Client.get(ip)
        log("Client connected from <#{ip}:#{port}>")
      end

      #
      # Run when a client has sent a chunk of data, it gets appended to a buffer
      # and a parsing attempt is made at the buffered data
      #
      # @param data [String] The received data chunk
      #
      def receive_data(data)
        data_chunk = data.chomp
        log("Received data chunk <#{data_chunk}>")
        msg_buf << data_chunk
        parse_messages_from_buffer
      end

      #
      # Attempts to parse fields from the message buffer, if the fields that get parsed
      # complete the temporary message, it is handled
      #
      def parse_messages_from_buffer
        while idx = msg_buf.index("\x01")
          field = msg_buf.slice!(0, idx + 1).gsub(/\x01\Z/, '')
          msg.append(field)

          if msg.complete?
            msg.handle
            msg = MessageBuffer.new
          end
        end
      end

      #
      # The data buffer string
      #
      def msg_buf
        @msg_buf ||= ''
      end

      #
      # The temporary message to which fields get appended
      #
      def msg
        @msg ||= MessageBuffer.new
      end

    end
  end
end

