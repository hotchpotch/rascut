begin
  require 'expect'
rescue LoadError
  require 'pathname'
  require Pathname.new(__FILE__).parent.parent.parent.join('vendor/ruby/expect')
end
require 'thread'
require 'rascut/file_observer'

module Rascut
  class FcshWrapper
    FCSH_RESULT_RE = /fcsh: Assigned (\d+) as the compile target id/
    FCSH_WAIT_RE = /^\(fcsh\)\s*$/

    attr_accessor :original_files, :files, :config, :target_script, :hooks
    def initialize(target_script, config)
      @target_script = target_script
      @config = config
      @hooks = Hash.new {|h, k| h[k] = []}
      @mutex = Mutex.new
      @compile_mutex = Mutex.new
      @compile_id = nil
      @process = nil
      @not_first_read = nil
    end

    def reload!
      if @compile_id
        process_sync_exec("clear #{@compile_id}")
        @compile_id = nil
      end
      call_hook :reload, @compile_id
    end

    def process_sync_exec(str, result_get = true)
      res = nil
      @mutex.synchronize do
        process.puts str
        res = read_result(process) if result_get
      end
      res
    end

    def close
      if process
        process.close
        call_hook :close
      end
    end

    def logger
      @config[:logger]
    end

    def mxmlc_cmd
      cmd = ['mxmlc', @config[:compile_config], @target_script].join(' ')
      logger.debug cmd
      cmd
    end

    def process
      unless @process
        orig_lang = ENV['LANG']
        ENV['LANG'] = 'C' # for flex3 sdk beta locale
        orig_java_options = ENV['_JAVA_OPTIONS']
        ENV['_JAVA_OPTIONS'] = orig_java_options.to_s + ' -Duser.language=en'
        @process = IO.popen(@config[:fcsh_cmd] + ' 2>&1', 'r+') unless @process
        ENV['LANG'] = orig_lang
        ENV['_JAVA_OPTIONS'] = orig_java_options
      end
      @process
    end

    def compile
      return false if @compile_mutex.locked?

      @compile_mutex.synchronize do
        logger.info "Compile Start"
        out = nil
        if @compile_id
          out = process_sync_exec "compile #{@compile_id}"
        else
          out = process_sync_exec mxmlc_cmd
          if m = out.match(FCSH_RESULT_RE)
            @compile_id = m[1]
          else
            raise "Can't get Compile ID\n" + out.to_s
          end
        end
        logger.info out
        if out.match(/bytes\)/)
          call_hook :compile_success, out
        else
          call_hook :compile_error, out
        end
        call_hook :compile, out
      end
    end

    def call_hook(name, *args)
      @hooks[name].each do |hook|
        if hook.arity == 0 || args.length == 0
          hook.call
        else
          hook.call(*args)
        end
      end
    end

    def read_result(process)
      unless @not_first_read 
        # first_time, FIXME uncool...
        process.expect(FCSH_WAIT_RE)
        @not_first_read = true
      end
      
      process.expect(FCSH_WAIT_RE).first.sub(FCSH_WAIT_RE, '')
    end
  end
end

