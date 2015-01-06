require 'eventmachine'

require 'fix/engine/message_buffer'

module Fix
  module Engine

    #
    # The client connection handling logic and method overrides
    #
    module Connection

      include Logger

      #
      # Grace time before we disconnect a client that doesn't reply to a test request
      #
      TEST_REQ_GRACE_TIME = 15

      attr_accessor :ip, :port, :msg_buf, :hrtbt_int, :last_request_at, :comp_id, :peer_comp_id

      #
      # Initialize the messages array, our comp_id, and the expected message sequence number
      #
      def post_init
        @expected_seq_num = 1

        # The sent messages
        @messages = []
      end

      #
      # The way we refer to our connection peer in various logs and messages
      #
      def peer
        "server"
      end

      #
      # Sets the heartbeat interval and schedules the keep alive call
      #
      # @param interval [Fixnum] The frequency in seconds at which a heartbeat should be emitted
      #
      def set_heartbeat_interval(interval)
        @hrtbt_int && raise("Can't set heartbeat interval twice")
        @heartbt_int = interval

        log("Heartbeat interval for #{peer} : <#{hrtbt_int}s>")
        @keep_alive_timer = EM.add_periodic_timer(1) { keep_alive }
      end

      #
      # Keeps the connection alive by sending regular heartbeats, and test request
      # messages whenever the connection has been idl'ing for too long
      #
      def keep_alive
        @last_send_at     ||= 0
        @last_request_at  ||= 0
        @hrtbt_int        ||= 0

        # Send a regular heartbeat when we don't send anything down the line for a while
        if @hrtbt_int > 0 && (@last_send_at < (Time.now.to_i - @hrtbt_int))
          send_heartbeat
        end

        # Trigger a test req message when we haven't received anything for a while
        if !@pending_test_req_id && (last_request_at < (Time.now.to_i - @hrtbt_int))
          send_test_request
        end
      end

      #
      # Sends a test request and expects an answer before +TEST_REQ_GRACE_TIME+
      #
      def send_test_request
        tr = FP::Messages::TestRequest.new
        tr.test_req_id = SecureRandom.hex(6)
        send_msg(tr)
        @pending_test_req_id = tr.test_req_id

        EM.add_timer(TEST_REQ_GRACE_TIME) do
          @pending_test_req_id && kill!
        end
      end

      #
      # Sends a heartbeat message with an optional +test_req_id+ parameter
      #
      # @param test_req_id [String] Sets the test request ID if sent in response to a test request
      #
      def send_heartbeat(test_req_id = nil)
        msg = FP::Messages::Heartbeat.new
        test_req_id && msg.test_req_id = test_req_id
        send_msg(msg)
      end

      #
      # Sends a +Fix::Protocol::Message+ to the connected peer
      #
      # @param msg [Fix::Protocol::Message] The message to send
      #
      def send_msg(msg)
        @send_seq_num ||= 1

        msg.msg_seq_num     = @send_seq_num
        msg.sender_comp_id  = @comp_id
        msg.target_comp_id  = @target_comp_id

        log("Sending <#{msg.class}> to #{peer} with sequence number <#{msg.msg_seq_num}>")

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

      #
      # Kills the connection after sending a logout message, if applicable
      #
      def kill!
        if @target_comp_id
          log("Logging out #{peer}")

          logout = FP::Messages::Logout.new
          logout.text = 'Bye!'

          send_msg(logout)
        end

        close_connection_after_writing
      end

      #
      # Cleans up after we're done
      #
      def unbind
        log("Terminating connection to #{peer}")
        @keep_alive_monitor && @keep_alive_monitor.cancel
      end

      #
      # Notifies the connected peer it fucked up somehow and kill the connection
      #
      # @param error_msg [String] The reason to embed in the reject message
      # @param msg_seq_num [Fixnum] The message sequence number this error pertains to
      #
      def peer_error(error_msg, msg_seq_num)
        log("Notifying #{peer} of error: <#{error_msg}> and terminating")

        rjct              = FP::Messages::Reject.new
        rjct.text         = error_msg
        rjct.ref_seq_num  = msg_seq_num

        send_msg(rjct)
        kill!
      end

      #
      # Maintains the message sequence consistency before handing off the message to +#handle_msg+
      #
      def process_msg(msg)
        @recv_seq_num = msg.msg_seq_num

        log("Received a <#{msg.class}> from #{peer} with sequence number <#{msg.msg_seq_num}>")

        # If sequence number == expected, then process it normally
        if (@expected_seq_num == @recv_seq_num)

          if @comp_id && msg.target_comp_id != @comp_id
            @client_comp_id = msg.sender_comp_id

            # Whoops, incorrect COMP_ID received, kill it with fire
            if (msg.target_comp_id != @comp_id)
              peer_error("Incorrect TARGET_COMP_ID in message, expected <#{@comp_id}>, got <#{msg.target_comp_id}>", msg.header.msg_seq_num)
            end

          else
            if msg.is_a?(FP::Messages::Heartbeat)
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
              run_message_handler(msg)
            end
          end

          @expected_seq_num += 1

        elsif (@expected_seq_num > @recv_seq_num)
          log("Ignoring message <#{msg}> with stale sequence number <#{msg.msg_seq_num}>, expecting <#{@expected_clt_seq_num}>")

        elsif (@expected_seq_num < @recv_seq_num) && @client_comp_id
          # Request missing range when detect a gap
          rr = FP::Messages::ResendRequest.new
          rr.begin_seq_no = @expected_clt_seq_num
          send_msg(rr)
        end

        self.last_request_at = Time.now.to_i
      end

      #
      # Runs the defined message handler for the message's class
      #
      # @param msg [FP::Message] The message to handle
      #
      def run_message_handler(msg)
        m = "on_#{msg.class.to_s.split('::').last.gsub(/(.)([A-Z])/, '\1_\2').downcase}".to_sym
        send(m, msg) if respond_to?(m)
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
          log("Raised exception by #{peer} when parsing data <#{data.gsub(/\x01/, '|')}>, terminating.")
          log($!.message + $!.backtrace.join("\n"))
          kill!
        end
      end

      #
      # Attempts to parse fields from the message buffer, if the fields that get parsed
      # complete the temporary message, it is processed
      #
      def parse_messages_from_buffer
        while idx = msg_buf.index("\x01")
          field = msg_buf.slice!(0, idx + 1).gsub(/\x01\Z/, '')
          msg.append(field)

          if msg.complete?
            parsed = msg.parse!
            if parsed.is_a?(FP::Message)
              process_msg(parsed)
            elsif parsed.is_a?(FP::ParseFailure)
              peer_error(parsed.errors.join(", "), @expected_clt_seq_num, target_comp_id: (@client_comp_id || 'UNKNOWN'))
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
      # Temporary message to which fields get appended
      #
      def msg
        @msg ||= MessageBuffer.new(@client)
      end

    end
  end
end

