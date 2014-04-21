#require 'fix/engine/logger'

require 'fix/protocol'

module Fix
  module Engine

    #
    # A FIX message to which fields get appended, once it is completed by a
    # proper terminator it is handled
    #
    class MessageBuffer

      include Logger

      attr_accessor :fields, :client

      def initialize(client)
        @fields = []
        @client = client
      end

      #
      # Append a single FIX field to the message
      #
      # @param fld [String] A FIX formatted field, such as "35=0\x01"
      #
      def append(fld)
        raise "Cannot append to complete message" if complete?
        field = fld.split('=')
        field[0] = field[0].to_i
        field[1] = field[1].gsub(/\x01\Z/, '')
        @fields << field
      end

      #
      # Returns true if the last field of the collection is a FIX checksum
      #
      # @return [Boolean] Whether the message is complete
      #
      def complete?
        (@fields.count > 0) && (@fields.last[0] == 10)
      end

      #
      # Nothing done for now
      #
      def handle
        msg = FP::Message.parse(to_s)

        klass = msg.class

        require 'pry'
        #binding.pry

        if (klass == FP::ParseFailure) || !msg.errors.count.zero?
          log("Failed to parse message <#{debug}>")
          log_errors(msg)

        elsif (klass == FP::Messages::Logon)
          log("Authenticating client <#{client.key}>")
          client.authenticate!(msg.username, msg.heart_bt_int, msg.msg_seq_num)
        end
      end

      def debug
        to_s('|')
      end

      def to_s(sep = "\x01")
        fields.map { |f| f.join('=') }.join(sep) + sep
      end

      def log_errors(msg)
        log("Invalid message received <#{debug}>")
        msg.errors.each { |e| log(" >>> #{e}") }
      end


    end
  end
end

