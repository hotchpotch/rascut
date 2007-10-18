
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

require 'rascut/utils'
require 'rascut/asdoc/data'
require 'thread'
require 'logger'
require 'pathname'
require 'open-uri'

module Rascut
  class Httpd
    include Utils
    class FileOnly < Rack::File
      def _call(env)
        if env["PATH_INFO"].include? ".."
          return [403, {"Content-Type" => "text/plain"}, ["Forbidden\n"]]
        end

        @path = env["PATH_INFO"] == '/' ? @root : F.join(@root, env['PATH_INFO'])
        ext = F.extname(@path)[1..-1]

        if F.file?(@path) && F.readable?(@path)
          [200, {
            "Content-Type"   => MIME_TYPES[ext] || "text/plain",
            "Content-Length" => F.size(@path).to_s
          }, self]
        else
          return [404, {"Content-Type" => "text/plain"},
            ["File not found: #{env["PATH_INFO"]}\n"]]
        end
      end
    end

    class FileIndex < Rack::File
      def _call(env)
        if env["PATH_INFO"].include? ".."
          return [403, {"Content-Type" => "text/plain"}, ["Forbidden\n"]]
        end

        @path = F.join(@root, env["PATH_INFO"])
        @path << '/index.html' if F.readable?(@path + '/index.html')
        @path.sub!(/\/$/, '')

        ext = F.extname(@path)[1..-1]

        if F.file?(@path) && F.readable?(@path)
          [200, {
            "Content-Type"   => MIME_TYPES[ext] || "text/plain",
            "Content-Length" => F.size(@path).to_s
          }, self]
        else
          return [404, {"Content-Type" => "text/plain"},
            ["File not found: #{env["PATH_INFO"]}\n"]]
        end
      end
    end



    def initialize(command)
      @command = command
      @threads = []
    end
    attr_reader :command

    def start
      swf_path = command.root.to_s
      logger.debug "swf_path: #{swf_path}"
      vendor = Pathname.new(__FILE__).parent.parent.parent.join('vendor')
      logger.debug "vendor_path: #{vendor}"
      reload = reload_handler
      index = index_handler

      #app = Rack::FixedBuilder.new do
      #  use Rack::ShowExceptions
      #  map('/reload') { run reload }
      #  map('/swf/') { run Rack::File.new(swf_path) }
      #  map('/') { run index }
      #end

      urls = []
      urls.concat(config_url_mapping) if config[:mapping]
      urls.concat(asdoc_mapping)

      urls.concat([
        ['/js/swfobject.js', Rack::ShowExceptions.new(Httpd::FileOnly.new(vendor.join('js/swfobject.js').to_s))],
        ['/swf', Rack::ShowExceptions.new(Rack::File.new(swf_path))],
        ['/aaa', Rack::ShowExceptions.new(Rack::File.new('/home/gorou/.rascut/asdoc/_home_gorou_svn_as3_papervision3d_trunk_src'))],
        ['/asdoc.json', Rack::ShowExceptions.new(asdoc_json_handler)],
        ['/reload', Rack::ShowExceptions.new(reload_handler)],
        ['/proxy', Rack::ShowExceptions.new(proxy_handler)],
        ['/', Rack::ShowExceptions.new(index_handler)]
      ])
      logger.debug 'url mappings: ' + urls.map{|u| u.first}.inspect
      app = Rack::URLMap.new(urls)
      port = config[:port] || 3001
      host = config[:bind_address] || '0.0.0.0'

      _args = [app, {:Host => host, :Port => port}]
      server_handler = detect_server
      Thread.new(_args) do |args|
        server_handler.run *args
      end
      logger.info "Start #{server_handler} http://#{host}:#{port}/"
    end

    def config
      command.config
    end

    def logger
      config.logger
    end

    def reload!
      while t = @threads.pop
        t.run
      end
    end

    private
    def config_url_mapping
      urls = []
      config[:mapping].each do |m|
        filepath = m[0]
        mappath = m[1]
        mappath = '/' + mappath if mappath[0..0] != '/'
        urls << [mappath, Rack::ShowExceptions.new(Rack::File.new(command.root.join(filepath).to_s))]
      end
      urls
    end

    def asdoc_mapping
      urls = []
      Pathname.glob(asdoc_home.to_s + '/*').each do |file|
        urls << ["/asdoc/#{file.basename}", Rack::ShowExceptions.new(FileIndex.new(file.to_s))]
      end
      urls << ["/asdoc/", Rack::ShowExceptions.new(FileIndex.new(asdoc_home.to_s))]
      urls
    end

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

        logger.debug 'httpd /reload reloading now'
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

    def proxy_handler
      Proc.new do |env|
        req = Rack::Request.new(env)
        url = req.query_string
        if url.empty?
          url = req.path_info[1..-1].gsub(%r{^(https?:/)/?}, '\\1/')
        end
        Rack::Response.new.finish do |r|
          open(url) { |io|
            r['Content-Type'] = io.content_type
            while part = io.read(8192)
              r.write part
            end
          }
        end
      end
    end

    def asdoc_json_handler
      @asdoc_data ||= Rascut::Asdoc::Data.asdoc_data
      require 'json'

      Proc.new do |env|
        req = Rack::Request.new(env)
        word = req['word']
        ary = []
        @asdoc_data.each do |i| 
          if i[:name].match(/^#{word}/)
            ary << i
            break if ary.length >= 30
          end
        end

        Rack::Response.new.finish do |r|
          r['Content-Type'] = 'text/plain'
          r.write ary.to_json
          #while part = io.read(8192)
          #  r.write part
          #end
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
      name = output_file(options[:compile_config]) || target_script
      name = File.basename(name, '.*')
      swf = "/swf/#{name}.swf"
      height, width = wh_parse options[:compile_config]
      bgcol = bg_parse options[:compile_config]
      # %Q[new SWFObject("#{swf}?#{Time.now.to_i}#{Time.now.usec}", "#{name}", "#{width}", "#{height}", '9', '#{bgcol}');]
      %Q[new SWFObject("#{swf}?" + (new Date()).getTime(), "idswf", "#{width}", "#{height}", '9', '#{bgcol}');]
    end

    def bg_parse(opt)
      if m = opt.to_s.match(/-default-background-color=(?:(?:0x)|#)([a-fA-F0-9]{3,6})/)
        '#' + m[1]
      else
        ''
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
      <div id="content"></div>

      <script type="text/javascript">
       var so = __SWFOBJECT__;
       window.onload = function() {
         __SWF_VARS__
         so.addVariable('rascut', 'true');
         so.write("content");
       }
      </script>
    </body>
</html>
    EOF

    RELOAD_SCRIPT = <<-EOF
    <script type="text/javascript">
    var Rascut = new Object;

    Rascut.xhr = (function() {
      if (typeof XMLHttpRequest != 'undefined') {
        return new XMLHttpRequest();
      } else {
        try {
          return new ActiveXObject("Msxml2.XMLHTTP");
        } catch(e) {
          return new ActiveXObject("Microsoft.XMLHTTP");
        }
      }
    })();

    Rascut.reloadObserver = function() {
        var x = Rascut.xhr;
        x.open('GET', '/reload?' + (new Date()).getTime(), true);
        x.onreadystatechange = function() {
          try {
            if (x.readyState == 4) {
              if (x.status == 200 && Number(x.responseText) == 1) {
                // thanks os0x!
                so.attributes.swf = so.attributes.swf + '+';
                so.write('content');
                Rascut.reloadObserver();
              } else {
                setTimeout(Rascut.reloadObserver, 5000);
              }
            }
          } catch(e) {
            setTimeout(Rascut.reloadObserver, 5000);
          }
        } 
        x.send(null);
    }

    Rascut.swf = function() {
       return document.getElementById('idswf');
    }

    Rascut.reloadObserver();
    </script>
    EOF
  end
end
