module Fix
  module Engine
    class Message

      attr_accessor :fields

      def initialize
        @fields = []
      end

      def append(fld)
        raise "Cannot append to complete message" if complete?
        field = fld.split('=')
        field[0] = field[0].to_i
        field[1] = field[1].gsub(/\x01\Z/, '')
        @fields << field
      end

      def complete?
        (@fields.count > 0) && (@fields.last[0] == 10)
      end

      def handle
        # NOOP
      end

    end
  end
end

