require "rascut/plugin/base"

module Rascut
  module Plugin
    class Growl < Base
      def run
        @growl = `which growlnotify`.chomp
        return unless $?.success?
        @command.wrapper.hooks[:compile_error] << method(:error)
        @command.wrapper.hooks[:compile_success] << method(:success)
      end

      def success(str)
        command = %Q[#{@growl} -w -m 'success' 'rascut compile results']
        system command
      end

      def error(str)
        command = %Q[#{@growl} -w -m 'failed' 'rascut compile results']
        system command
      end

      def strip_ansi(m)
        m.gsub(/\e\[[^m]*m/, '')
      end
    end
  end
end
