
require 'rubygems'
require 'hpricot'
require 'pp'
require 'nkf'
require 'logger'
require 'pathname'
require 'uri'
require 'rascut/utils'
require 'rascut/asdoc/parser'
require 'rascut/asdoc/data'

module Rascut
  module Asdoc
    class Generator 
      include Utils

      def initialize(logger = nil)
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::DEBUG
        @asdoc = 'asdoc'
      end
      attr_accessor :asdoc

      def generate_asdoc(source_path)
          @logger.info "generate documents: #{source_path}"
          cmd = "#{asdoc} -doc-sources '#{source_path}' -output '#{asdoc_home.join(path_escape(source_path.to_s))}'"
          @logger.debug cmd
          `#{cmd}`
      end

      def generate_asdoc_by_config(flex_config)
        source = Hpricot(flex_config)
        files = source.search('source-path path-element').map {|el| Pathname.new(el.inner_text) }
        files.each do |file|
          generate_asdoc file.realpath
        end
      end

      def generate_list
        @logger.info "generate list"
        Pathname.glob("#{asdoc_home}/*").each do |asdoc|
          @logger.info "#{asdoc}"
          Pathname.glob("#{asdoc}/*/**/*.html") do |file|
            next if file.to_s.match(/((class-list.html)|(package-detail.html))$/)
            r = Rascut::Asdoc::Parser.new(file.read, @logger)
            r.parse
            #pp file.to_s, r.package, r.classname#, r.methods
            list = {
              :package => r.package,
              :classname => r.classname,
              :methods => r.methods,
              :filename => file.relative_path_from(asdoc).to_s,
              :asdoc_dir => asdoc.basename.to_s,
            }
            rascut_db do |db|
              db[:asdoc] ||= {}
              db[:asdoc][list[:asdoc_dir]] ||= []
              db[:asdoc][list[:asdoc_dir]] << list
            end
          end
        end
        #generate_json
      end

      def generate_json
        @logger.info "generate asdoc's index(json)."
        json = Rascut::Asdoc::Data.asdoc_json
        asdoc_home.join('asdoc.json').open('w') {|f| f.puts json }
      end
    end
  end
end

if __FILE__ == $0
  include Rascut::Asdoc
  flex_config = '/home/gorou/local/flex2/frameworks/flex-config.xml'
  g = Generator.new #
  g.asdoc = '/home/gorou/local/flex3/bin/asdoc'
  #g.generate_asdoc_by_config(open(flex_config).read)
  g.generate_asdoc('/home/gorou/svn/as3/swfassist/src')
  g.generate_list
end

