require 'eventmachine'

require 'fix/engine/message_buffer'
require 'fix/engine/client'

module Fix
  module Engine

    #
    # The client connection wrapper, when one needs to connect to an engine
    #
    class ClientConnection < EM::Connection

      include Logger

      attr_accessor :ip, :port, :client, :msg_buf, :hrtbt_int, :last_request_at

      #
      # Our own company ID
      #
      DEFAULT_CLIENT_COMP_ID  = 'PYMBTC'
      DEFAULT_SERVER_COMP_ID  = 'PAYMIUM'
      DEFAULT_USERNAME        = 'JOE'

      def initialize(*args)
        if opts = args.pop
          @username = opts[:username]
          @our_comp_id = opts[:our_comp_id]
          @server_comp_id = opts[:server_comp_id]
        end
      end

      #
      # Run after we've connected to the server
      #
      def post_init
        @expected_clt_seq_num = 1

        @our_comp_id    ||= DEFAULT_CLIENT_COMP_ID
        @server_comp_id ||= DEFAULT_SERVER_COMP_ID

        log("Connected to server sending a logon message with our COMP_ID being <#{@our_comp_id}>")

        # The sent messages
        @messages = []

        logon = FP::Messages::Logon.new
        logon.username            = @username || DEFAULT_USERNAME
        logon.target_comp_id      = @server_comp_id
        logon.sender_comp_id      = @our_comp_id 
        logon.reset_seq_num_flag  = true
        send_msg(logon)
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
        msg.sender_comp_id  = @our_comp_id
        msg.target_comp_id  ||= @server_comp_id

        log("Sending <#{msg.class}> to server with sequence number <#{msg.msg_seq_num}>")

        if msg.valid?
          @messages[msg.msg_seq_num] = msg
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
        log("Logging out from server")
        logout = FP::Messages::Logout.new
        logout.text = 'Bye!'
        send_msg(logout)

        close_connection_after_writing
      end

      def unbind
      end

      def handle_msg(msg)
        @recv_seq_num = msg.msg_seq_num

        log("Received a <#{msg.class}> from <#{ip}:#{port}> with sequence number <#{msg.msg_seq_num}>")

        # If sequence number == expected, then process it normally
        if (@expected_clt_seq_num == @recv_seq_num)

          if msg.is_a?(FP::Messages::Logon)
            log("Authenticated as <#{msg.username}> with heartbeat interval of <#{msg.heart_bt_int}s> and message sequence number start <#{msg.msg_seq_num}>")
            on_logon

          elsif msg.is_a?(FP::Messages::Heartbeat)
            # If we were expecting an answer to a test request we can sign it off and
            # cancel the scheduled connection termination
            if @pending_test_req_id && msg.test_req_id && (@pending_test_req_id == msg.test_req_id)
              @pending_test_req_id = nil
            end

          elsif msg.is_a?(FP::Messages::TestRequest)
            # Answer test requests with a matching heartbeat
            hb = FP::Messages::Heartbeat.new
            hb.test_req_id = msg.test_req_id
            send_msg(hb)

          elsif msg.is_a?(FP::Messages::ResendRequest)
            # Re-send requested message range
            @messages[msg.begin_seq_no, msg.end_seq_no.zero? ? @messages.length : msg.end_seq_no].each do |m|
              log("Re-sending <#{m.class}> to <#{ip}:#{port}> with sequence number <#{m.msg_seq_num}>")
              send_data(m.dump)
              @last_send_at = Time.now.to_i
            end

          elsif msg.is_a?(FP::Message)
            on_message(msg)
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

      def on_message(msg)
      end

      def on_logon
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

        begin
          parse_messages_from_buffer
        rescue
          log("Raised exception when parsing data <#{data.gsub(/\x01/, '|')}>, terminating.")
          log($!.message + $!.backtrace.join("\n"))
          kill!
        end
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
            if parsed.is_a?(FP::Message)
              handle_msg(parsed)
            elsif parsed.is_a?(FP::ParseFailure)
              server_error(parsed.errors.join(", "), @expected_clt_seq_num, target_comp_id: (@client_comp_id || 'UNKNOWN'))
            end
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

      def server_error(error_msg, msg_seq_num, opts = {})
        log("Server error: \"#{error_msg}\"")
        kill!
      end


    end
  end
end

