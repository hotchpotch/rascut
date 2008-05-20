
require 'rubygems'
require 'hpricot'
require 'pp'
require 'nkf'
require 'logger'

module Rascut
  module Asdoc
    class Parser
      def initialize(source, logger = nil)
        source = NKF::nkf('-m0 -w', source)
        @logger = logger || Logger.new(STDOUT)
        @logger.level = Logger::DEBUG
        @source = Hpricot(source)
        @methods = []
        @package = nil
        @classname = nil
      end
      attr_reader :methods, :package, :classname

      def parse
        title = @source.at('title').inner_text
        @package = title.split('.')[0..-2].join('.')
        @classname = title.split('.')[-1].split(/\s/)[0]
        @logger.debug "parse: #{@package} #{@classname}"
        @source.search('td.summaryTableSignatureCol').each {|el| 
          next if el.at('td.summaryTableInheritanceCol') || !el.at('a')

          begin
            method = {
              :href => el.at('a')['href'],
              :name => el.at('a').inner_text.strip,
              :code => el.search('div:not(.summaryTableDescription)').inner_text.strip.gsub("\n", ' '),
            }
            if summary = el.at('div.summaryTableDescription')
              s = summary.inner_text.strip.gsub("\n", ' ')
              if s[0..0] == '[' && s[-1..-1] == ']'
                method[:code] << " #{s}"
                method[:code].strip!
              else
                method[:summary] = s
              end
            end
            @methods << method
          rescue NoMethodError => e
            @logger.debug e.message
            @logger.debug el.inner_text.strip.gsub("\n", ' ')
          end
        }
        @logger.debug "parse: #{@methods.length} methods found"
      end
    end
  end
end

if __FILE__ == $0
  require 'pathname'
  #Pathname.glob('/home/gorou/local/docs/flex201_documentation/langref/**/*.html') do |file|
  Pathname.glob('/home/gorou/svn/as3rails2u/trunk/asdoc-output/*/**/*.html') do |file|
    puts file.to_s
    r = Rascut::Asdoc::Parser.new(file.read)
    r.parse
    pp r.package, r.classname#, r.methods
  end
  #Rascut::AsdocParser.new(open('/home/gorou/local/docs/flex201_documentation/langref/flash/display/Sprite.html').read).parse
  #Rascut::AsdocParser.new(open('/home/gorou/svn/as3rails2u/trunk/asdoc-output/com/rails2u/net/JSONPLoader.html').read).parse
end

