
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

module Rascut
  class Httpd
    def initialize(command)
      @command = command
      @threads = []
    end
    attr_reader :command

    def start
      swf_path = command.root.to_s
      reload = reload_handler
      index = index_handler

      #app = Rack::FixedBuilder.new do
      #  use Rack::ShowExceptions
      #  map('/reload') { run reload }
      #  map('/swf/') { run Rack::File.new(swf_path) }
      #  map('/') { run index }
      #end

      app = Rack::URLMap.new([
        ['/swf', Rack::ShowExceptions.new(Rack::File.new(swf_path))],
        ['/reload', Rack::ShowExceptions.new(reload_handler)],
        ['/', Rack::ShowExceptions.new(index_handler)]
      ])
      port = command.config.params[:port] || 3001
      host = command.config.params[:bind_address] || '0.0.0.0'

      _args = [app, {:Host => host, :Port => port}]
      server_handler = detect_server
      Thread.new(_args) do |args|
        server_handler.run *args
      end
      "Start #{server_handler} http://#{host}:#{port}/"
    end


    def reload!
      while t = @threads.pop
        t.run
      end
    end

    private
    def detect_server
      begin 
        case command.config.params[:server]
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
      if command.config.params[:template] && File.readable?(command.config.params[:template])
        res = File.read(command.config.params[:template]) + "\n" + RELOAD_SCRIPT
      else 
        res = INDEX.sub('__SWFOBJECT__', swftag(command.target_script, command.config.params)).sub('<!--__RELOAD__-->', RELOAD_SCRIPT)
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
      <script type="text/javascript">
/**
 * SWFObject v1.4.4: Flash Player detection and embed - http://blog.deconcept.com/swfobject/
 *
 * SWFObject is (c) 2006 Geoff Stearns and is released under the MIT License:
 * http://www.opensource.org/licenses/mit-license.php
 *
 * **SWFObject is the SWF embed script formerly known as FlashObject. The name was changed for
 *   legal reasons.
 */
if(typeof deconcept == "undefined") var deconcept = new Object();
if(typeof deconcept.util == "undefined") deconcept.util = new Object();
if(typeof deconcept.SWFObjectUtil == "undefined") deconcept.SWFObjectUtil = new Object();
deconcept.SWFObject = function(swf, id, w, h, ver, c, useExpressInstall, quality, xiRedirectUrl, redirectUrl, detectKey){
  if (!document.getElementById) { return; }
  this.DETECT_KEY = detectKey ? detectKey : 'detectflash';
  this.skipDetect = deconcept.util.getRequestParameter(this.DETECT_KEY);
  this.params = new Object();
  this.variables = new Object();
  this.attributes = new Array();
  if(swf) { this.setAttribute('swf', swf); }
  if(id) { this.setAttribute('id', id); }
  if(w) { this.setAttribute('width', w); }
  if(h) { this.setAttribute('height', h); }
  if(ver) { this.setAttribute('version', new deconcept.PlayerVersion(ver.toString().split("."))); }
  this.installedVer = deconcept.SWFObjectUtil.getPlayerVersion();
  if(c) { this.addParam('bgcolor', c); }
  var q = quality ? quality : 'high';
  this.addParam('quality', q);
  this.setAttribute('useExpressInstall', useExpressInstall);
  this.setAttribute('doExpressInstall', false);
  var xir = (xiRedirectUrl) ? xiRedirectUrl : window.location;
  this.setAttribute('xiRedirectUrl', xir);
  this.setAttribute('redirectUrl', '');
  if(redirectUrl) { this.setAttribute('redirectUrl', redirectUrl); }
}
deconcept.SWFObject.prototype = {
  setAttribute: function(name, value){
    this.attributes[name] = value;
  },
  getAttribute: function(name){
    return this.attributes[name];
  },
  addParam: function(name, value){
    this.params[name] = value;
  },
  getParams: function(){
    return this.params;
  },
  addVariable: function(name, value){
    this.variables[name] = value;
  },
  getVariable: function(name){
    return this.variables[name];
  },
  getVariables: function(){
    return this.variables;
  },
  getVariablePairs: function(){
    var variablePairs = new Array();
    var key;
    var variables = this.getVariables();
    for(key in variables){
      variablePairs.push(key +"="+ variables[key]);
    }
    return variablePairs;
  },
  getSWFHTML: function() {
    var swfNode = "";
    if (navigator.plugins && navigator.mimeTypes && navigator.mimeTypes.length) { // netscape plugin architecture
      if (this.getAttribute("doExpressInstall")) { this.addVariable("MMplayerType", "PlugIn"); }
      swfNode = '<embed type="application/x-shockwave-flash" src="'+ this.getAttribute('swf') +'" width="'+ this.getAttribute('width') +'" height="'+ this.getAttribute('height') +'"';
      swfNode += ' id="'+ this.getAttribute('id') +'" name="'+ this.getAttribute('id') +'" ';
      var params = this.getParams();
       for(var key in params){ swfNode += [key] +'="'+ params[key] +'" '; }
      var pairs = this.getVariablePairs().join("&");
       if (pairs.length > 0){ swfNode += 'flashvars="'+ pairs +'"'; }
      swfNode += '/>';
    } else { // PC IE
      if (this.getAttribute("doExpressInstall")) { this.addVariable("MMplayerType", "ActiveX"); }
      swfNode = '<object id="'+ this.getAttribute('id') +'" classid="clsid:D27CDB6E-AE6D-11cf-96B8-444553540000" width="'+ this.getAttribute('width') +'" height="'+ this.getAttribute('height') +'">';
      swfNode += '<param name="movie" value="'+ this.getAttribute('swf') +'" />';
      var params = this.getParams();
      for(var key in params) {
       swfNode += '<param name="'+ key +'" value="'+ params[key] +'" />';
      }
      var pairs = this.getVariablePairs().join("&");
      if(pairs.length > 0) {swfNode += '<param name="flashvars" value="'+ pairs +'" />';}
      swfNode += "</object>";
    }
    return swfNode;
  },
  write: function(elementId){
    if(this.getAttribute('useExpressInstall')) {
      // check to see if we need to do an express install
      var expressInstallReqVer = new deconcept.PlayerVersion([6,0,65]);
      if (this.installedVer.versionIsValid(expressInstallReqVer) && !this.installedVer.versionIsValid(this.getAttribute('version'))) {
        this.setAttribute('doExpressInstall', true);
        this.addVariable("MMredirectURL", escape(this.getAttribute('xiRedirectUrl')));
        document.title = document.title.slice(0, 47) + " - Flash Player Installation";
        this.addVariable("MMdoctitle", document.title);
      }
    }
    if(this.skipDetect || this.getAttribute('doExpressInstall') || this.installedVer.versionIsValid(this.getAttribute('version'))){
      var n = (typeof elementId == 'string') ? document.getElementById(elementId) : elementId;
      n.innerHTML = this.getSWFHTML();
      return true;
    }else{
      if(this.getAttribute('redirectUrl') != "") {
        document.location.replace(this.getAttribute('redirectUrl'));
      }
    }
    return false;
  }
}

/* ---- detection functions ---- */
deconcept.SWFObjectUtil.getPlayerVersion = function(){
  var PlayerVersion = new deconcept.PlayerVersion([0,0,0]);
  if(navigator.plugins && navigator.mimeTypes.length){
    var x = navigator.plugins["Shockwave Flash"];
    if(x && x.description) {
      PlayerVersion = new deconcept.PlayerVersion(x.description.replace(/([a-zA-Z]|\s)+/, "").replace(/(\s+r|\s+b[0-9]+)/, ".").split("."));
    }
  }else{
    // do minor version lookup in IE, but avoid fp6 crashing issues
    // see http://blog.deconcept.com/2006/01/11/getvariable-setvariable-crash-internet-explorer-flash-6/
    try{
      var axo = new ActiveXObject("ShockwaveFlash.ShockwaveFlash.7");
    }catch(e){
      try {
        var axo = new ActiveXObject("ShockwaveFlash.ShockwaveFlash.6");
        PlayerVersion = new deconcept.PlayerVersion([6,0,21]);
        axo.AllowScriptAccess = "always"; // throws if player version < 6.0.47 (thanks to Michael Williams @ Adobe for this code)
      } catch(e) {
        if (PlayerVersion.major == 6) {
          return PlayerVersion;
        }
      }
      try {
        axo = new ActiveXObject("ShockwaveFlash.ShockwaveFlash");
      } catch(e) {}
    }
    if (axo != null) {
      PlayerVersion = new deconcept.PlayerVersion(axo.GetVariable("$version").split(" ")[1].split(","));
    }
  }
  return PlayerVersion;
}
deconcept.PlayerVersion = function(arrVersion){
  this.major = arrVersion[0] != null ? parseInt(arrVersion[0]) : 0;
  this.minor = arrVersion[1] != null ? parseInt(arrVersion[1]) : 0;
  this.rev = arrVersion[2] != null ? parseInt(arrVersion[2]) : 0;
}
deconcept.PlayerVersion.prototype.versionIsValid = function(fv){
  if(this.major < fv.major) return false;
  if(this.major > fv.major) return true;
  if(this.minor < fv.minor) return false;
  if(this.minor > fv.minor) return true;
  if(this.rev < fv.rev) return false;
  return true;
}
/* ---- get value of query string param ---- */
deconcept.util = {
  getRequestParameter: function(param) {
    var q = document.location.search || document.location.hash;
    if(q) {
      var pairs = q.substring(1).split("&");
      for (var i=0; i < pairs.length; i++) {
        if (pairs[i].substring(0, pairs[i].indexOf("=")) == param) {
          return pairs[i].substring((pairs[i].indexOf("=")+1));
        }
      }
    }
    return "";
  }
}
/* fix for video streaming bug */
deconcept.SWFObjectUtil.cleanupSWFs = function() {
  if (window.opera || !document.all) return;
  var objects = document.getElementsByTagName("OBJECT");
  for (var i=0; i < objects.length; i++) {
    objects[i].style.display = 'none';
    for (var x in objects[i]) {
      if (typeof objects[i][x] == 'function') {
        objects[i][x] = function(){};
      }
    }
  }
}
// fixes bug in fp9 see http://blog.deconcept.com/2006/07/28/swfobject-143-released/
deconcept.SWFObjectUtil.prepUnload = function() {
  __flash_unloadHandler = function(){};
  __flash_savedUnloadHandler = function(){};
  if (typeof window.onunload == 'function') {
    var oldUnload = window.onunload;
    window.onunload = function() {
      deconcept.SWFObjectUtil.cleanupSWFs();
      oldUnload();
    }
  } else {
    window.onunload = deconcept.SWFObjectUtil.cleanupSWFs;
  }
}
if (typeof window.onbeforeunload == 'function') {
  var oldBeforeUnload = window.onbeforeunload;
  window.onbeforeunload = function() {
    deconcept.SWFObjectUtil.prepUnload();
    oldBeforeUnload();
  }
} else {
  window.onbeforeunload = deconcept.SWFObjectUtil.prepUnload;
}
/* add Array.push if needed (ie5) */
if (Array.prototype.push == null) { Array.prototype.push = function(item) { this[this.length] = item; return this.length; }}

/* add some aliases for ease of use/backwards compatibility */
var getQueryParamValue = deconcept.util.getRequestParameter;
var FlashObject = deconcept.SWFObject; // for legacy support
var SWFObject = deconcept.SWFObject;
      </script>
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
