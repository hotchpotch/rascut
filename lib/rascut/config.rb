require 'optparse'
require 'rascut/logger'
require 'logger'

module Rascut
  class Config
    DEFAULT_CONFIG  = {
      :interval => 1,
      :compile_config => nil,
      :file_observing => true,
      :fcsh_cmd => 'fcsh',
      :ext => ['as', 'css', 'mxml'],
      :logger => Rascut::Logger.new(STDOUT),
    }

    def initialize
      @params = DEFAULT_CONFIG.dup
      @params[:logger].level = ::Logger::INFO
    end
    attr_accessor :params

    def [](name)
      @params[name]
    end

    def logger
      @params[:logger]
    end

    def parse_argv!(argv)
      op = OptionParser.new
      op.banner = 'Usage: $ rascut HelloWrold.as'

      #op.on('-a', 'Apollo compile mode') do |v| 
      #  @params[:apollo] = true
      #  @params[:compile_config] = '+configname=apollo' 
      #end

      op.on('-b=VAL', '--bind-address=VAL', 'server bind address(default 0.0.0.0)') {|v| @params[:bind_address] = v }
      op.on('--compile-config=VAL', '-c=VAL', 'mxmlc compile config ex:) --compile-config="-benchmark -strict=true"') do |v| 
        if @params[:compile_config]
          @params[:compile_config] << ' '  <<  v 
        else
          @params[:compile_config] = v 
        end
      end 

      op.on('--fcsh-cmd=VAL', 'fcsh command path') {|v| @params[:fcsh_cmd] = v }
      @params[:observe_files] = []
      op.on('-I=VAL', '--observe-files=VAL', 'observe files and directories path') {|v| @params[:observe_files] << v }

      if @params[:observe_files].empty?
        @params[:observe_files] << '.'
      end

      op.on('-h', '--help', 'show this message') { puts op; Kernel::exit 1 }
      op.on('-i=VAL', '--interval=VAL', 'interval time(min)') {|v| @params[:interval] = v.to_i }
      op.on('-l=VAL', '--log=VAL', 'showing flashlog.txt') {|v| @params[:flashlog] = v }
      op.on('-m=VAL', '--mapping=VAL', 'server mapping path :example) -m "../assets=assets" -m "../images/=img"') {|v| 
        @params[:mapping] ||= []
        @params[:mapping] << v.split('=', 2)
      }
      op.on('--no-file-observe', "don't observing files") {|v| @params[:file_observing] = false }
      op.on('--observe-ext=VAL', 'observe ext ex:) --observe-ext="as3,actionscript3,css,mxml"') {|v| @params[:ext] = v.split(',') }
      op.on('--server', '-s', 'start autoreload webserver') {|v| @params[:server] = true }
      op.on('--server-handler=val', 'set server hander :example) --server-handler=webrick') {|v| @params[:server] = v }
      op.on('--port=val', '-p=val', 'server port(default: 3001)') {|v| @params[:port] = v.to_i }
      op.on('--plugin=VAL', 'load plugin(s)') {|v| 
        @params[:plugin] ||= []
        @params[:plugin] << v
      }
      op.on('-t=VAL', '--template=VAL', 'server use template file') {|v| @params[:template] = v }
      op.on('-v', '--verbose', 'detail messages') {|v| @params[:logger].level = Logger::DEBUG }
      op.on('--version', 'show version') {|v| 
        puts "rascut #{Rascut::VERSION}"
        exit 0
      }
      op.parse! argv
      @params[:logger].debug 'config' + @params.inspect
    end

    def merge_config(file)
      @params.merge!  YAML.load_file(file)
    end
  end
end
