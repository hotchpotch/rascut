
require 'rubygems'
require 'mongrel'
require 'mongrel/handlers'

require 'rascut/utils'
require 'rascut/asdoc/data'
require 'thread'
require 'logger'
require 'pathname'
require 'json'

module Rascut
  module Asdoc
    class Httpd
      include Utils
      def initialize
        @logger = Logger.new(STDOUT)
        @threads = []
        @data = Rascut::Asdoc::Data.asdoc_data
      end
      attr_reader :command

      def run 
        port = config[:port] || 3002
        host = config[:bind_address] || '0.0.0.0'

        @http_server = Mongrel::HttpServer.new(host, port)
        @http_server.register('/', Mongrel::DirHandler.new(asdoc_home.to_s))
        @http_server.register('/json', json_handler)
        @http_server.run
        logger.info "Start Mongrel: http://#{host}:#{port}/"
      end
      attr_reader :data

      def json_handler
        ProcHandler.new do |req, res|
          ary = []
          params = Mongrel::HttpRequest.query_parse(req.params['QUERY_STRING'])
          if word = params['word']
            method_re, class_re, package_re = *search_regexes(word.strip)

            c = 0
            if method_re
              @data[:methods].each do |i| 
                if i[:name].match method_re
                  next if class_re && !i[:classname].match(class_re)
                  next if package_re && !i[:package].match(package_re)
                  ary << i
                  c += 1
                  break if c >= 20
                end
              end
            elsif class_re
              @data[:classes].each do |i| 
                if i[:classname].match class_re
                  next if package_re && !i[:package].match(package_re)
                  ary << i
                  c += 1
                  break if c >= 20
                end
              end
            elsif package_re
              @data[:packages].each do |i| 
                if i[:package].match package_re
                  ary << i
                  c += 1
                  break if c >= 20
                end
              end
            end
          end

          res.start do |head, out|
            head['Content-Type'] = 'application/json'
            out << ary.to_json
          end
        end
      end

      def search_regexes(w)
        method_re = class_re = package_re = nil

        words = w.split(/\s+/)
        words.each do |word|
          case word[0..0]
          when '.'
            #package
            package_re = /#{Regexp.escape(word[1..-1])}/
          when /[A-Z]/
            # class
            class_re = /#{Regexp.escape(word)}/
            #when '#'
          else
            # method
            method_re = /^#{Regexp.escape(word.sub('#', ''))}/
          end
        end
        [method_re, class_re, package_re]
      end


      def stop
        # XXX
        # @http_server.stop
      end

      def config
        #command.config
        {}
      end

      def logger
        @logger
      end
    end
  end
end

if __FILE__ == $0
  Rascut::Asdoc::Httpd.new.run
  Thread.stop
end

