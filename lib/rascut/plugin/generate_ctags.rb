# append your ~/.ctags 
# --regex-actionscript=/^.*function[\t ]+([gs]et[\t ]+)?([A-Za-z0-9_]+)[\t ]*\(/\2/I,inner/i
# --regex-actionscript=/^.*class[\t ]+([A-Za-z0-9_]+)/\1/I,inner/i
#
require 'rascut/plugin/base'
require 'pathname'

module Rascut
  module Plugin
    class GenerateCtags < Base
      def run
        @ctags_cmd = config[:ctags] || 'ctags'
        @command.file_observer.add_update_handler method(:generate_ctags)
      end

      def generate_ctags
        `#{@ctags_cmd} -f #{@command.root.join('tags')} #{@command.root}/**/*.as #{@command.root}/**.as`
      end
    end
  end
end
