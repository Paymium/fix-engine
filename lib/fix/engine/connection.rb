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

      #
      # Timespan during which a client must send a logon message after connecting
      #
      LOGON_TIMEOUT = 10

      #
      # Timespan during which we will wait for a heartbeat response from the client
      #
      HRTBT_TIMEOUT = 10

      #
      # Grace time before we disconnect a client that doesn't reply to a test request
      #
      TEST_REQ_GRACE_TIME = 15

      attr_accessor :ip, :port, :client, :msg_buf, :hrtbt_int, :last_request_at

      #
      # Our own company ID
      #
      DEFAULT_COMP_ID = 'PYMBTC'

      #
      # Run after a client has connected
      #
      def post_init
        @port, @ip            = Socket.unpack_sockaddr_in(get_peername)
        @client               = Client.get(ip, port, self)
        @expected_clt_seq_num = 1

        log("Client connected from <#{@client.key}>, expecting logon message in the next #{LOGON_TIMEOUT}s")

        # TODO : Read configuration here
        @comp_id = 'PYMBTCDEV'

        # TODO : How do we test this
        # TODO : Do we cancel the periodic timeout when leaving ?
        EM.add_timer(LOGON_TIMEOUT) { logon_timeout }
      end

      def logon_timeout
        unless client.has_session?
          log("Client <#{client.key}> failed to authenticate before timeout, closing connection")
          close_connection_after_writing
          Client.delete(ip, port)
        end
      end

      def manage_hrtbts
        @last_send_at     ||= 0
        @last_request_at  ||= 0
        @hrtbt_int        ||= 0

        # Send a regular heartbeat when we don't send anything down the line for a while
        if @hrtbt_int > 0 && (@last_send_at < (Time.now.to_i - @hrtbt_int))
          send_heartbeat
        end

        # Trigger a test req message when we haven't received anything for a while
        if !@pending_test_req_id && (last_request_at < (Time.now.to_i - @hrtbt_int))
          tr = FP::Messages::TestRequest.new
          tr.test_req_id = SecureRandom.hex(6)
          send_msg(tr)
          @pending_test_req_id = tr.test_req_id

          EM.add_timer(TEST_REQ_GRACE_TIME) do
            @pending_test_req_id && kill!
          end
        end
      end

      def send_msg(msg)
        @send_seq_num ||= 1

        msg.msg_seq_num     = @send_seq_num
        msg.target_comp_id  = @client_comp_id
        msg.sender_comp_id  = @comp_id || DEFAULT_COMP_ID

        log("Sending <#{msg.class}> to <#{ip}:#{port}> with sequence number <#{msg.msg_seq_num}>")

        if msg.valid?
          send_data(msg.dump)
          @send_seq_num += 1
          @last_send_at = Time.now.to_i
        else
          log(msg.errors.join(', '))
          raise "Tried to send invalid message!"
        end
      end

      def set_heartbeat_interval(interval)
        @hrtbt_int && raise("Can't set heartbeat interval twice")
        @hrtbt_int = interval

        log("Heartbeat interval for <#{ip}:#{port}> : <#{hrtbt_int}s>")
        @hrtbt_monitor  = EM.add_periodic_timer(1) { manage_hrtbts }
      end

      def kill!
        log("Logging out client <#{ip}:#{port}>")
        logout = FP::Messages::Logout.new
        logout.text = 'Bye!'
        send_msg(logout)

        close_connection_after_writing
      end

      def unbind
        log("Terminating client <#{ip}:#{port}>")
        Client.delete(ip, port)
        @hrtbt_monitor && @hrtbt_monitor.cancel
      end

      def client_error(error_msg, msg_seq_num, opts = {})
        log("Client error: \"#{error_msg}\"")
        rjct = FP::Messages::Reject.new
        rjct.text = error_msg
        rjct.ref_seq_num = msg_seq_num
        rjct.target_comp_id = opts[:target_comp_id] if opts[:target_comp_id]
        send_msg(rjct)
        kill!
      end

      def handle_msg(msg)
        @recv_seq_num = msg.msg_seq_num
       
        # Handle resend request
        # Handle test request

        # If sequence number == expected, then process it normally
        if (@expected_clt_seq_num == @recv_seq_num)

          if @comp_id && msg.target_comp_id != @comp_id
            @client_comp_id = msg.sender_comp_id

            if (msg.target_comp_id != @comp_id)
              client_error("Incorrect TARGET_COMP_ID in message, expected <#{@comp_id}>, got <#{msg.target_comp_id}>", msg.msq_seq_num)
            end

          else
            log("Received a <#{msg.class}> from <#{ip}:#{port}> with sequence number <#{msg.msg_seq_num}>")

            if !@client_comp_id && msg.is_a?(FP::Messages::Logon)
              log("Client authenticated as <#{msg.username}> with heartbeat interval of <#{msg.heart_bt_int}s> and message sequence number start <#{msg.msg_seq_num}>")
              client.client_id  = msg.username
              @client_comp_id   = msg.sender_comp_id
              set_heartbeat_interval(msg.heart_bt_int)

              logon = FP::Messages::Logon.new
              logon.username        = msg.username
              logon.target_comp_id  = msg.sender_comp_id
              logon.sender_comp_id  = msg.target_comp_id 
              send_msg(logon)

            elsif @client_comp_id && msg.is_a?(FP::Messages::Logon)
              client_error("Expecting only a single logon message during a session", msg.msg_seq_num)

            elsif !@client_comp_id
              client_error("The session must be started with a logon message", msg.msg_seq_num, target_comp_id: msg.sender_comp_id)

            elsif msg.is_a?(FP::Messages::Heartbeat)
              # If we were expecting an answer to a test request we can sign it off and
              # cancel the scheduled connection termination
              if @pending_test_req_id && msg.test_req_id && (@pending_test_req_id == msg.test_req_id)
                @pending_test_req_id = nil
              end
            end
          end

          @expected_clt_seq_num += 1

        elsif (@expected_clt_seq_num > @recv_seq_num)
          log("Ignoring message <#{msg}> with stale sequence number <#{msg.msg_seq_num}>, expecting <#{@expected_clt_seq_num}>")

        elsif (@expected_clt_seq_num < @recv_seq_num) && @client_comp_id
          # Request missing range when detect a gap
          rr = FP::Messages::ResendRequest.new
          rr.begin_seq_no = @expected_clt_seq_num
          send_msg(rr)
        end

        self.last_request_at = Time.now.to_i
      end

      #
      # Run when a client has sent a chunk of data, it gets appended to a buffer
      # and a parsing attempt is made at the buffered data
      #
      # @param data [String] The received data chunk
      #
      def receive_data(data)
        data_chunk = data.chomp
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
            parsed = msg.parse!
            parsed && handle_msg(parsed)
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

      def send_heartbeat(test_req_id = nil)
        msg = FP::Messages::Heartbeat.new
        test_req_id && msg.test_req_id = test_req_id
        send_msg(msg)
      end

    end
  end
end

