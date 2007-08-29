
module Rascut
  module Plugin
    class Base
      def initialize(command)
        @command = command
      end

      def config
        # ...
        {}
      end

      def run
        raise 'should\'d be run method override!'
      end
    end
  end
end
