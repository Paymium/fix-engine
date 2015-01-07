require 'fix/engine/connection'
require 'fix/engine/client'

module Fix
  module Engine

    #
    # The server connection wrapper, used when accepting a connection
    #
    module ServerConnection

      include Connection

      #
      # Timespan during which a client must send a logon message after connecting
      #
      LOGON_TIMEOUT = 10

      #
      # Run after a client has connected
      #
      def post_init
        super

        @port, @ip  = Socket.unpack_sockaddr_in(get_peername)
        @client     = Client.get(ip, port, self)

        log("Client connected #{peer}, expecting logon message in the next #{LOGON_TIMEOUT}s")

        EM.add_timer(LOGON_TIMEOUT) { logon_timeout }
      end

      #
      # Logs the client out should he fail to authenticate before +LOGON_TIMEOUT+ seconds
      #
      def logon_timeout
        unless @target_comp_id
        log("Client #{peer} failed to authenticate before timeout, closing connection")
        close_connection_after_writing
        client.delete
        end
      end

      #
      # Returns the currently connected client
      #
      def client
        Client.get(ip, port, self)
      end

      #
      # The way we refer to our connection peer in various logs and messages
      #
      def peer
        "<#{client.key}>"
      end

      #
      # Deletes the +FE::Client+ instance after the connection is terminated
      #
      def unbind
        super
        client.delete
      end

      #
      # We override +FE::Connection#run_message_handlers+ to add some session-related logic
      #
      def run_message_handler(msg)
        if !@target_comp_id && msg.is_a?(FP::Messages::Logon)
          log("Peer authenticated as <#{msg.username}> with heartbeat interval of <#{msg.heart_bt_int}s> and message sequence number start <#{msg.msg_seq_num}>")
          client.username = msg.username
          @target_comp_id = msg.sender_comp_id
          set_heartbeat_interval(msg.heart_bt_int)

          logon                     = FP::Messages::Logon.new
          logon.username            = msg.username
          logon.target_comp_id      = msg.sender_comp_id
          logon.sender_comp_id      = msg.target_comp_id 
          logon.reset_seq_num_flag  = true

          send_msg(logon)

        elsif @target_comp_id && msg.is_a?(FP::Messages::Logon)
          log("Received second logon message, reset_seq_num_flag <#{msg.reset_seq_num_flag}>")
          if msg.reset_seq_num_flag = 'Y'
            @send_seq_num = 1
            @messages = []
          end

        elsif !@target_comp_id
          peer_error("The session must be started with a logon message", msg.msg_seq_num, target_comp_id: msg.sender_comp_id)

        else
          super(msg)

        end
      end

    end
  end
end

