
require 'rubygems'
require 'mongrel'
require 'mongrel/handlers'

require 'rascut/utils'
require 'rascut/asdoc/data'
require 'thread'
require 'logger'
require 'pathname'
require 'open-uri'

module Rascut
  class Httpd
    include Utils

    def initialize(command)
      @command = command
      @http_servet = 
      @threads = []
    end
    attr_reader :command

    def run 
      swf_path = command.root.to_s
      logger.debug "swf_path: #{swf_path}"
      vendor = Pathname.new(__FILE__).parent.parent.parent.join('vendor')
      logger.debug "vendor_path: #{vendor}"

      file_mappings = [
        ['/js/swfobject.js', vendor.join('js/swfobject.js').to_s],
        ['/swf', swf_path]
      ]
      file_mappings.concat(config_url_mapping) if config[:mapping]
      logger.debug 'url mappings: ' + file_mappings.inspect

      port = config[:port] || 3001
      host = config[:bind_address] || '0.0.0.0'

      reload = reload_handler
      index = index_handler

      @http_server = Mongrel::HttpServer.new(host, port)
      file_mappings.each do |mapping|
        @http_server.register(mapping[0], Mongrel::DirHandler.new(mapping[1]))
      end
      @http_server.register('/proxy', proxy_handler)
      @http_server.register('/reload', reload_handler)
      @http_server.register('/', index_handler)
      @http_server.run
      logger.info "Start Mongrel: http://#{host}:#{port}/"
    end

    def stop
      # XXX
      # @http_server.stop
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
        urls << [mappath, command.root.join(filepath).to_s]
      end
      urls
    end

    #def asdoc_mapping
    #  urls = []
    #  Pathname.glob(asdoc_home.to_s + '/*').each do |file|
    #    urls << ["/asdoc/#{file.basename}", Rack::ShowExceptions.new(FileIndex.new(file.to_s))]
    #  end
    #  urls << ["/asdoc/", Rack::ShowExceptions.new(FileIndex.new(asdoc_home.to_s))]
    #  urls
    #end

    def reload_handler
      #Proc.new do |env|
      ProcHandler.new do |req, res|
        @threads << Thread.current
        Thread.stop

        logger.debug 'httpd /reload reloading now'
        res.start do |head, out|
          head["Content-Type"] = "text/plain"
          out << 1
        end
        #Rack::Response.new.finish do |r|
        #  r.write '1'
        #end
      end
    end

    def index_handler
      if config[:template] && File.readable?(config[:template])
        res = File.read(config[:template]) + "\n" + RELOAD_SCRIPT
      else 
        res = INDEX.sub('__SWFOBJECT__', swftag(command.target_script, config)).sub('<!--__RELOAD__-->', RELOAD_SCRIPT)
      end

      ProcHandler.new do |req, response|
      #Proc.new do |env|
      #req = Rack::Request.new(env)
        res.sub!('__SWF_VARS__', swfvars(req.params))
        response.start do |head, out|
          out << res
        end
        #Rack::Response.new.finish do |r|
        #  r.write res
        #end
      end
    end

    def proxy_handler
      ProcHandler.new do |req, res|
        url = req.params['QUERY_STRING']
        if url.empty?
          url = req.path_info[1..-1].gsub(%r{^(https?:/)/?}, '\\1/')
        end
        res.start do |head, out|
          open(url) { |io|
            head['Content-Type'] = io.content_type
            while part = io.read(8192)
              out << part
            end
          }
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
