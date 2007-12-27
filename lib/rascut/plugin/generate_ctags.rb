# append your ~/.ctags 
# --langdef=actionscript
# --langmap=actionscript:.as
# --regex-actionscript=/^.*function[\t ]+([gs]et[\t ]+)?([A-Za-z0-9_]+)[\t ]*\(/\2/F,function/i
# --regex-actionscript=/^.*class[\t ]+([A-Za-z0-9_]+)/\1/C,class/i
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
        `#{@ctags_cmd} -R --langmap=actionscript:.as -f #{@command.root.join('tags')}`
      end
    end
  end
end
