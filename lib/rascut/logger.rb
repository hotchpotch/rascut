require 'logger'

module Rascut
  class Logger < ::Logger
    # This code from ActiveSupport
    private
      alias old_format_message format_message
      if method_defined?(:formatter=)
        def format_message(severity, timestamp, progname, msg)
          "[#{Time.now.strftime('%m/%d %H:%M:%S')}] #{msg}\n"
        end
      else
        def format_message(severity, timestamp, msg, progname)
          "[#{Time.now.strftime('%m/%d %H:%M:%S')}] #{msg}\n"
        end
      end
  end
end
