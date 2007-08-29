
require 'rascut/plugin/base'
require 'pathname'

module Rascut
  module Plugin
    class WriteFcshErrorOutput < Base
      def run
        file = config[:filename] || Pathname.new(ENV['HOME']).join('.rascut/error_output')
        @path = Pathname.new(file.to_s)

        @command.wrapper.hooks[:compile_error] << method(:write_error_output)
        @command.wrapper.hooks[:compile_success] << method(:write_error_none)
      end

      def write_error_output(str)
        str.each_line do |line|
          if line.match 'Error: '
            @path.open('w'){|f| f.puts line.chomp }
            break
          end
        end
      end

      def write_error_none(str)
        @path.open('w'){|f| f.write '' }
      end

    end
  end
end
