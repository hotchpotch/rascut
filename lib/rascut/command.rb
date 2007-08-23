require 'optparse'
require 'rascut/fcsh_wrapper'
require 'rascut/logger'
require 'rascut/config'
require 'pathname'
require 'yaml'

module Rascut
  class Command
    OBSERVE_EXT = %w(as mxml)
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
      files = observe_files()
      @wrapper = FcshWrapper.new(@target_script, @config, files)
      start_server if @config.params[:server] && !@config.params[:apollo]
      apollo() if @config.params[:apollo]
      setting_signals()
      @wrapper.hooks[:compile_success] = method(:compile_success_proc)
      read_log_loop() if @config.params[:flashlog] 
      @wrapper.run
    end
    attr_reader :config, :root, :target_script

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
      self.exit()
    end

    def sig_usr2
      # reload and restart
      reload!
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

    def reload!
      logger.info 'Reloading...'
      new_files = observe_files()
      nf = (new_files - @wrapper.original_files).uniq
      @wrapper.set_original_files(new_files)
      unless nf.empty?
        logger.info "Found new files #{nf.join(' ')}"
      end
      @wrapper.compile
    end

    def observe_files
      e = ext @config
      if !@config.params[:observe_files].empty?
        res = []
        @config.params[:observe_files].each do |f|
          f = Pathname.new(f)
          if f.file? && e.split(',').include?(f.extname.sub(/^\./, ''))
            res << f.to_s
          elsif f.directory?
            res.concat Dir.glob(f.to_s + "/{*,**/*}.{#{e}}")
          end
        end
        res.uniq
      else
        res = Dir.glob(@root.to_s + "/{*,**/*}.{#{e}}")
      end
      # delete -keep generated files
      res.delete_if {|f| f.to_s.match('/generated/') }
    end

    def ext(config)
      e = OBSERVE_EXT.join ','
      if config.params[:ext]
        e << ',' + config.params[:ext].strip
      end
      e
    end
  end
end
