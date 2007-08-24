
begin
  require 'rack'
rescue LoadError
  require 'rubygems'
  gem 'rack'
end

require 'rack/showexceptions'
require 'rack/urlmap'
require 'rack/file'
require 'rack/request'
require 'rack/response'
require 'thread'
require 'logger'
require 'pathname'

module Rascut
  class Httpd
    def initialize(command)
      @command = command
      @threads = []
    end
    attr_reader :command

    def start
      swf_path = command.root.to_s
      vendor = Pathname.new(__FILE__).parent.parent.parent.join('vendor')
      reload = reload_handler
      index = index_handler

      #app = Rack::FixedBuilder.new do
      #  use Rack::ShowExceptions
      #  map('/reload') { run reload }
      #  map('/swf/') { run Rack::File.new(swf_path) }
      #  map('/') { run index }
      #end

      app = Rack::URLMap.new([
        ['/js', Rack::ShowExceptions.new(Rack::File.new(vendor.join('js')))],
        ['/swf', Rack::ShowExceptions.new(Rack::File.new(swf_path))],
        ['/reload', Rack::ShowExceptions.new(reload_handler)],
        ['/', Rack::ShowExceptions.new(index_handler)]
      ])
      port = config[:port] || 3001
      host = config[:bind_address] || '0.0.0.0'

      _args = [app, {:Host => host, :Port => port}]
      server_handler = detect_server
      Thread.new(_args) do |args|
        server_handler.run *args
      end
      "Start #{server_handler} http://#{host}:#{port}/"
    end

    def config
      command.config
    end

    def reload!
      while t = @threads.pop
        t.run
      end
    end

    private
    def detect_server
      begin 
        case config[:server]
        when 'mongrel'
          require_mongrel_handler
        when 'webrick'
          require_webrick_handler
        else
          require_mongrel_handler
        end
      rescue Exception => e
        require_webrick_handler
      end
    end

    def require_mongrel_handler
      begin
        require 'mongrel'
      rescue LoadError
        require 'rubygems'
        gem 'mongrel', '> 1.0'
      end
      require 'rack/handler/mongrel'
      Rack::Handler::Mongrel
    end

    def require_webrick_handler
      require 'webrick'
      require 'rack/handler/webrick'
      Rack::Handler::WEBrick
    end

    def reload_handler
      Proc.new do |env|
        @threads << Thread.current
        Thread.stop

        Rack::Response.new.finish do |r|
          r.write '1'
        end
      end
    end

    def index_handler
      if config[:template] && File.readable?(config[:template])
        res = File.read(config[:template]) + "\n" + RELOAD_SCRIPT
      else 
        res = INDEX.sub('__SWFOBJECT__', swftag(command.target_script, config)).sub('<!--__RELOAD__-->', RELOAD_SCRIPT)
      end

      Proc.new do |env|
        req = Rack::Request.new(env)
        res.sub!('__SWF_VARS__', swfvars(req.GET))
        Rack::Response.new.finish do |r|
          r.write res
        end
      end
    end

    def swfvars(vars)
      res = []
      vars.each do |key, value|
        res << %Q[so.addVariable('#{key}', '#{value}');]
      end
      res.join("\n")
    end

    def swftag(target_script, options)
      name = output_file(options[:compile_options]) || target_script
      name = File.basename(name, '.*')
      swf = "/swf/#{name}.swf"
      height, width = wh_parse options[:compile_options]
      bgcol = bg_parse options[:compile_options]
      %Q[new SWFObject("#{swf}?#{Time.now.to_i}#{Time.now.usec}", "#{name}", "#{width}", "#{height}", '9', '#{bgcol}');]
    end

    def bg_parse(opt)
      if m = opt.to_s.match(/-default-background-color=0x([a-fA-F0-9]{3,6})/)
        '#' + m[1]
      else
        '#ffffff'
      end
    end

    def wh_parse(opt)
      if m = opt.to_s.match(/-default-size\s+(\d+)\s+(\d+)/)
        m.to_a[1..2]
      else
        ['100%', '100%']
      end
    end

    def output_file(opt)
      if m = opt.to_s.match(/-(o|output)\s+([^\s]+)/)
        m[2]
      else
        nil
      end
    end

    INDEX = <<-EOF
<html>
    <head>
      <title>Rascut</title>
      <style>
      * {
          margin:0;
          padding:0;
      }
      #content {
          text-align:center;
      }
      </style>
      <script type="text/javascript" src="/js/swfobject.js"></script>
      <!--__RELOAD__-->
    </head>
    <body>
      <div id="content">
      </div>

      <script type="text/javascript">
       var so = __SWFOBJECT__;
       __SWF_VARS__
       so.addVariable('rascut', 'true');
       so.write("content");
      </script>
    </body>
</html>
    EOF

    RELOAD_SCRIPT = <<-EOF
        <script type="text/javascript">
        function xhr() {
          if (typeof XMLHttpRequest != 'undefined') {
            return new XMLHttpRequest();
          } else {
            try {
              return new ActiveXObject("Msxml2.XMLHTTP");
            } catch(e) {
              return new ActiveXObject("Microsoft.XMLHTTP");
            }
          }
        }
        function _reload() {
            var x = xhr();
            x.open('GET', '/reload?' + (new Date()).getTime(), true);
            x.onreadystatechange = function() {
              try {
                if (x.readyState == 4) {
                  if (x.status == 200 && Number(x.responseText) == 1) {
                    location.reload(true);
                  } else {
                    _reload();
                  }
                }
              } catch(e) {
                setTimeout(_reload, 5000);
              }
            } 
            x.send(null);
        }
        _reload();
        </script>
    EOF
  end
end
