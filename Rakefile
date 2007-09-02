# -*- ruby -*-

require 'logger'
require 'rubygems'
require 'hoe'
$LOAD_PATH << './lib'
require './lib/rascut.rb'
require 'tmpdir'

ENV['HOME'] ||= Dir.tmpdir # for Hoe's bug.

Hoe.new('rascut', Rascut::VERSION) do |p|
  p.rubyforge_name = 'hotchpotch'
  p.author = 'yuichi tateno'
  p.email = 'hotchpotch@nononospam@gmail.com'
  p.summary = 'Ruby ActionSCript UTility'
  p.description = p.paragraphs_of('README.txt', 2..5).join("\n\n")
  p.url = p.paragraphs_of('README.txt', 0).first.split(/\n/)[1..-1]
  p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")

  p.extra_deps << ['mongrel']
  p.extra_deps << ['rake']
  p.extra_deps << ['hoe']
  p.extra_deps << ['rack']
end

# vim: syntax=Ruby
