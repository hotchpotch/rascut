#!/usr/bin/env ruby

require 'pathname'
require 'rubygems'
require 'hpricot'

res = open('/home/gorou/.vim/dict/as3packagelist.core').read.split("\n")

flex_config = Hpricot(open('/home/gorou/local/flex3/frameworks/flex-config.xml').read)
flex_config.search('source-path > path-element').each do |el|
  path = Pathname.new el.inner_text
  root = path.parent.realpath.to_s + '/'

  files = Pathname.glob("#{path}/**/*.as").concat(Pathname.glob("#{path}/*.as"))
  files = files.map {|pa| pa.realpath.to_s.sub(root, '').split('/') } #.find_all{|i| i.last[0..0] =~ /[A-Z]/}
  files.each do |fa|
    fa[-1] = File.basename(fa.last, '.*')
    cname = fa.last
    pname = fa.join('.').sub(/^src\./, '').sub(/^as3\./, '')
    res << "#{cname} #{pname}"
  end
end

res = res.sort.uniq
open('/home/gorou/.vim/dict/as3packagelist', 'w') {|f|
  f.puts res.join("\n")
}
