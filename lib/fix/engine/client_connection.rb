require 'fix/engine/connection'

module Fix
  module Engine

    #
    # The client connection wrapper, used in order to connect a remote FIX server
    #
    module ClientConnection

      include Connection

      attr_accessor :username

      #
      # Run after we've connected to the server
      #
      def post_init
        super

        log("Connecting to server sending a logon message with our COMP_ID <#{@comp_id}>")

        @logged_in = false

        EM.next_tick { send_logon }
      end

      #
      # Sends a logon message to the server we're connected to
      #
      def send_logon
        logon = FP::Messages::Logon.new
        logon.username            = @username
        logon.target_comp_id      = @peer_comp_id
        logon.sender_comp_id      = @comp_id 
        logon.reset_seq_num_flag  = true
        send_msg(logon)
      end

      #
      # Consider ourselves logged-in if we receive on of these
      #
      def on_logon(msg)
        @logged_in = true
      end

    end
  end
end

