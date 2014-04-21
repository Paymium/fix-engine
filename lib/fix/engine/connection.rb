require 'eventmachine'

require 'fix/engine/client'
require 'fix/engine/message_buffer'

module Fix
  module Engine

    #
    # The client connection handling logic and method overrides
    #
    module Connection

      include Logger

      #
      # Timespan during which a client must send a logon message after connecting
      #
      LOGON_TIMEOUT = 10

      attr_accessor :ip, :port, :client, :msg_buf, :hrtbt_int

      #
      # Run after a client has connected
      #
      def post_init
        @port, @ip  = Socket.unpack_sockaddr_in(get_peername)
        @client     = Client.get(ip, port, self)
        log("Client connected from <#{@client.key}>, expecting logon message in the next #{LOGON_TIMEOUT}s")
        EM.add_timer(LOGON_TIMEOUT) { logon_timeout }
      end

      def logon_timeout
        unless client.has_session?
          log("Client <#{client.key}> failed to authenticate before timeout, closing connection")
          close_connection_after_writing
          Client.delete(ip, port)
        end
      end

      #
      # Run when a client has sent a chunk of data, it gets appended to a buffer
      # and a parsing attempt is made at the buffered data
      #
      # @param data [String] The received data chunk
      #
      def receive_data(data)
        msg_buf << data.chomp
        parse_messages_from_buffer
      end

      #
      # Attempts to parse fields from the message buffer, if the fields that get parsed
      # complete the temporary message, it is handled
      #
      def parse_messages_from_buffer
        puts msg_buf
        msg_buf.gsub!('|', "\x01")
        puts msg_buf

        while idx = msg_buf.index("\x01")
          field = msg_buf.slice!(0, idx + 1).gsub(/\x01\Z/, '')
          msg.append(field)

          if msg.complete?
            log("Received message <#{msg.debug}>")
            msg.handle
            msg = nil
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
        @msg ||= MessageBuffer.new(@client)
      end

      def set_heartbeat_interval(interval)
        @hrtbt_int && raise("Can't set heartbeat interval twice")
        @hrtbt_int = interval
        log("Sending heartbeats every <#{hrtbt_int}s>")
        EM.add_periodic_timer(hrtbt_int) { send_heartbeat }
      end

      def send_heartbeat
        log("Sending heartbeat to client <#{client.key}>")
        msg = FP::Messages::Heartbeat.new
        msg.target_comp_id = 'What?'
        msg.sender_comp_id = 'Whut?'
        msg.msg_seq_num = 0
        send_data(msg.dump)
      end

    end
  end
end

