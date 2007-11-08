require 'pathname'
require 'uri'
require 'pstore'
require 'rubygems'
require 'mongrel/handlers'

module Rascut
  module Utils
    def home
      if ENV['HOME']
        home = Pathname.new ENV['HOME']
      elsif ENV['USERPROFILE']
        # win32
        home = Pathname.new ENV['USERPROFILE']
      else
        raise 'HOME dir not found.'
      end

      home = home.join('.rascut')
      home.mkpath
      home
    end
    module_function :home

    def asdoc_home
      path = home.join('asdoc')
      path.mkpath
      path
    end
    module_function :asdoc_home

    def rascut_db_path
      home.join('rascut.db')
    end
    module_function :rascut_db_path

    def rascut_db(readonly = false)
      db = PStore.new home.join('rascut.db').to_s
      db.transaction(readonly) do 
        yield db
      end
    end
    module_function :rascut_db

    def rascut_db_read(&block)
      rascut_db(true, &block)
    end
    module_function :rascut_db_read

    def path_escape(name)
      URI.encode(name.to_s.gsub('/', '_'), /[^\w_\-]/)
    end
    module_function :path_escape

    class ProcHandler < Mongrel::HttpHandler
      def initialize(&block)
        @proc = block
      end

      def process(req, res)
        @proc.call(req, res)
      end
    end
  end
end
