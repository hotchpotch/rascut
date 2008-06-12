#!/usr/bin/env ruby

require 'pathname'
require 'rubygems'
require 'hpricot'

home = Pathname.new(ENV['HOME'])
tagfile = home.join('.vim/tags/actionscript.tags')
ctags = 'ctags'
flex_framework_src = home.join 'local/flex3/frameworks/projects/framework/src/'

flex_config = Hpricot(home.join('local/flex3/frameworks/flex-config.xml').read)
pathes = flex_config.search('source-path > path-element').map do |el|
  path = Pathname.new el.inner_text
  path.parent.realpath.to_s + '/'
end

pathes << flex_framework_src

pathes.map! {|f| f.to_s + '**/*.as' }

flag = false
pathes.each do |path|
  cmd = "#{ctags} #{flag ? '--append=yes' : ''} -f #{tagfile} #{Dir.glob(path).join(' ')}"
  system cmd
  flag = true
end

#res = res.sort.uniq
#open('/home/gorou/.vim/dict/as3packagelist', 'w') {|f|
#  f.puts res.join("\n")
#}

