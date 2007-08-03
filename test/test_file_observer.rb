#!/usr/bin/env ruby
$LOAD_PATH << File.expand_path(File.dirname(__FILE__) + "/../lib")
require 'rascut/file_observer'
require 'test/unit'
require 'tmpdir'
require 'pathname'

class FileObserverTest < Test::Unit::TestCase
  def setup
    @tmpdir = Pathname.new(Dir.tmpdir).join('test_file_observer_' + Time.now.to_i.to_s)
    @tmpdir.mkpath

    @fo = Rascut::FileObserver.new(@tmpdir.to_s, :interval => 1)
    @update_files = []

    @fo.add_update_handler method(:save_files)

    @call_update_handler_flag = false
    @fo.add_update_handler method(:call_update_handler)

    @fo.run
  end

  def call_update_handler(files)
    @call_update_handler_flag = true
  end

  def save_files(files)
    @update_files << files
  end

  def test_fileput
    sleep 1
    @tmpdir.join('foo.txt').open('w') {|f| f.puts 'file'}
    sleep 1
    assert @call_update_handler_flag

    @call_update_handler_flag = false
    sleep 1
    @tmpdir.join('foo.txt').open('w+') {|f| f.puts 'file'}
    sleep 1
    assert @call_update_handler_flag

    @call_update_handler_flag = false
    sleep 1
    assert(!@call_update_handler_flag)
  end

  def test_fileput_with_ext
    @fo.options[:ext] = ['txt']
    sleep 1
    @tmpdir.join('foo.txt').open('w') {|f| f.puts 'file'}
    sleep 1
    assert @call_update_handler_flag
  end

  def test_fileput_with_ext_nomatch
    @fo.options[:ext] = ['nontext']
    sleep 1
    @tmpdir.join('foo.txt').open('w') {|f| f.puts 'file'}
    sleep 1
    assert !@call_update_handler_flag
  end

  def teardown
    @fo.stop
    @tmpdir.rmtree
  end
end
