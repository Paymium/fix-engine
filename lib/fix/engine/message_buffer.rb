module Fix
  module Engine

    class MessageBuffer

      def initialize
        @fields = []
      end

      def append(fld)
        field = fld.split('=')
        field[0] = field[0].to_i
        @fields << field
      end

      def complete?
        (@fields.count > 0) && (@fields.last[0] == 10)
      end

      def handle
        puts @fields.inspect
      end
    end
  end
end
