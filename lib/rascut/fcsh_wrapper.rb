require 'expect'
require 'thread'

module Rascut
  class FcshWrapper
    FCSH_RESULT_RE = /fcsh: Assigned (\d+) as the compile target id/
    FCSH_WAIT_RE = /^\(fcsh\)\s*$/

    attr_accessor :original_files, :files, :config, :target_script, :hooks
    def initialize(target_script, config, original_files = [])
      @target_script = target_script
      @config = config

      set_original_files(original_files)
      @compile_id = nil
      @hooks = {}
      @mutex = Mutex.new
      @compile_mutex = Mutex.new
    end

    def set_original_files(of)
      @original_files = of
      files_setting()
    end

    def reload!
      files_setting()
      if @compile_id
        process_sync_exec("clear #{@compile_id}")
        @compile_id = nil
      end
      call_hook(:reload)
    end

    def process_sync_exec(str, result_get = true)
      res = nil
      @mutex.synchronize do
        @process.puts str
        res = read_result(@process) if result_get
      end
      res
    end

    def run
      loop do
        compile() if file_update?
        sleep [@config.params[:interval], 1].max
      end
    end

    def close
      if @process
        #logger.info process_sync_exec('quit', false)
        @process.close
        call_hook(:close)
      end
    end

    def logger
      @config.params[:logger]
    end

    def files_setting
      @files = {}
      [@target_script, @original_files].flatten.uniq.each do |file|
        @files[Pathname.new(file)] = Time.at(0)
      end
    end

    def file_update?
      update_files = []
      @files.each do |file, timestamp|
        if !file.file? 
          logger.warn "#{file} not found..."
          @files.delete file
        elsif file.mtime > timestamp
          update_files << file.basename.to_s
          @files[file] = file.mtime
        end
      end
      update_files.uniq!
      if update_files.empty?
        false
      else
        logger.info "Found update files: #{update_files.join(' ')}"
        @hooks.call if @hooks[:file_update]
        true
      end
    end

    def mxmlc_cmd
      ['mxmlc', @config.params[:compile_options], @target_script].join(' ')
    end

    def compile
      return false if @compile_mutex.locked?

      @compile_mutex.synchronize do
        logger.info "Compile Start"
        out = nil
        @process = IO.popen(@config.params[:fcsh_cmd] + ' 2>&1', 'r+') unless @process
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
          call_hook :compile_success
        end
        call_hook :compile
      end
    end

    def call_hook(name)
      @hooks[name].call if @hooks[name]
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

