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
      # Parses the message into a FP::Message instance
      #
      def parse
        msg = FP.parse(to_s)
        if (msg.class == FP::ParseFailure) || !msg.errors.count.zero?
          log("Failed to parse message <#{debug}>")
          log_errors(msg)
        end

        msg
      end

      #
      # Parses the message and empties the fields array so a new message
      # can start to get buffered right away
      #
      def parse!
        parsed = parse
        @fields = []
        parsed
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

