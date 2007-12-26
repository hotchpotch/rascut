
require 'rascut/plugin/base'

module Rascut
  module Plugin
    class Screen < Base
      STATUS = %q[%H %`%-w%{=b bw}%n %t%{-}%+w %=]

      SCREEN_CMD = 'screen'
      SCREEN_COLOR = {
        :black => 'dd',
        :blue  => 'bk',
        :green => 'gk',
        :red   => 'rw',
      }

      def run
        @command.wrapper.hooks[:compile_start] << method(:start)
        @command.wrapper.hooks[:compile_error] << method(:error)
        @command.wrapper.hooks[:compile_success] << method(:success)
      end

      def start
        message 'C'
      end

      def error
        message 'E', :red
      end

      def success
        message 'S', :blue
      end

      def message(msg, color = :black)
        if run_screen_session?
          col = SCREEN_COLOR[color]
          msg = %Q[ %{=b #{col}} #{msg} %{-}]
          send_cmd(msg)
        end
      end

      def clear
        send_cmd('')
      end

      def run_screen_session?
        str = `#{SCREEN_CMD} -ls`
        str.match(/(\d+) Socket/) && ($1.to_i > 0)
      end

      def send_cmd(msg)
        cmd = %Q[#{SCREEN_CMD} -X eval 'hardstatus alwayslastline "#{(STATUS + msg).gsub('"', '\"')}"']
        system cmd
      end
    end
  end
end
