module Fix
  module Engine

    #
    # A FIX message to which fields get appended, once it is completed by a
    # proper terminator it is handled
    #
    class MessageBuffer

      attr_accessor :fields

      def initialize
        @fields = []
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
        # NOOP
      end

    end
  end
end

