require 'optparse'
require 'rascut/fcsh_wrapper'
require 'rascut/logger'
require 'rascut/config'
require 'pathname'
require 'yaml'

module Rascut
  class Command
    def initialize
      @logger = Logger.new(STDOUT)
    end
    attr_accessor :logger

    def run(argv)
      @config = Config.new

      if ENV['HOME'] && File.readable?(ENV['HOME'] + '/.rascut')
        @config.merge_config(ENV['HOME'] + '/.rascut')
      end

      if File.readable?('.rascut')
        @config.merge_config(@config, '.rascut')
      end

      @config.parse_argv!(argv)

      unless @target_script = argv.first
        warn 'Target script is not found.'
        Kernel::exit 1
      end

      @root = Pathname.new(@target_script).dirname.realpath
      @wrapper = FcshWrapper.new(@target_script, @config)

      start_server if @config[:server]
      setting_signals
      @wrapper.hooks[:compile_success] = method(:compile_success_proc)


      if @config[:file_observing]
        @file_observer = FileObserver.new(@config[:observe_files], 
                                          :interval => @config[:interval],
                                          :ext => @config[:ext],
                                          :logger => @config[:logger],
                                          :update_handler => method(:file_update_handler))
        @file_observer.run
      end

      read_log_loop if @config[:flashlog] 

      @wrapper.compile 
      Thread.stop
    end
    attr_reader :config, :root, :target_script

    def file_update_handler
      @wrapper.compile
    end

    def apollo
      create_appolo_xml_template
    end

    def create_appolo_xml_template
      name = File.basename @target_script, '.*' 
      xml = <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<application xmlns="http://ns.adobe.com/apollo/application/1.0.M3" appId="com.example.example" version="0.1">
  <properties>
    <name>#{name}</name>
    <description>#{name}</description>
    <publisher>Example Publisher</publisher>
    <copyright>2007</copyright>
  </properties>

  <rootContent systemChrome="none" transparent="true" visible="false">#{name}.swf</rootContent>
</application>
EOF
      xmlfile = @root.join(name + '-app.xml')
      unless xmlfile.exist?
        xmlfile.open('w+') {|f| f.puts xml}
        @logger.info "generate xml: #{xmlfile.basename}" 
      end
    end

    def read_log_loop
      log = Pathname.new(@config.params[:flashlog])
      return unless (log && log.file?)

      Thread.new(log) do |log|
        flashlog_timestamp ||= log.mtime

        log.open('r') do |f|
          f.read
          loop do
            if log.mtime > flashlog_timestamp
              f.rewind
              text = f.read
              if text.length == 0
                f.rewind
                text = f.read
              end
              logger.info("FLASHLOG\n" + text) unless text.strip.empty?
              flashlog_timestamp = log.mtime
            end
            sleep 1
          end
        end
      end
    end

    def compile_success_proc
      if @httpd
        @httpd.reload!
      end
    end

    def start_server
      require 'rascut/httpd'
      @httpd = Httpd.new(self)
      logger.info @httpd.start
    end

    def setting_signals
      methods(true).each do |mname|
        if m = mname.match(/^sig_(.+)$/)
          begin
            Signal.trap(m[1].upcase) { method(mname).call }
          rescue ArgumentError
          end
        end
      end
    end

    def sig_int
      logger.debug 'SIG_INT'
      self.exit()
    end

    def sig_usr2
      logger.debug 'SIG_USR2'
      @wrapper.compile
    end

    def exit
      logger.info 'exiting...'
      begin
        @wrapper.close 
      rescue Exception => e
        logger.error e.inspect
      end
      Kernel::exit 1
    end
  end
end
