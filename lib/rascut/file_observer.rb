require 'pathname'
require 'find'
require 'logger'

module Rascut
  class FileObserver
    DEFAULT_OPTIONS = {
      :interval => 1,
      :ignore_files => [],
      :ignore_dirs => [],
      :logger => Logger.new(STDOUT),
      :ext => nil
    }

    def initialize(files, options)
      @files = {}
      @dirs = {}
      @options = DEFAULT_OPTIONS.merge options
      @update_handlers = []
      @th = nil

      if options[:update_handler]
        add_update_handler options.delete(:update_handler)
      end

      observe files
    end
    attr_accessor :options

    def logger
      options[:logger]
    end

    def run
      if @th
        @th.run
      else
        @th = Thread.start do
          loop do
            update_check
            sleep @options[:interval]
          end
        end
      end
    end

    def add_update_handler(handler)
      unless @update_handlers.include? handler
        @update_handlers << handler
      end
    end

    def remove_update_handler(handler)
      @update_handlers.delete_if {|h| h == handler}
    end

    private

    def update_check
      update_files = []
      check_dirs

      @files.each do |file, mtime|
        if !file.readable?
          @files.delete file
        elsif file.mtime > mtime
          @files[file] = file.mtime
          update_files << file
        end
      end

      unless update_files.empty?
        @update_handlers.each do |handler|
          if handler.arity == 1
            handler.call update_files
          else
            handler.call
          end
        end
      end
    end

    def check_dirs
      dfiles = []
      @dirs.each do |dir, mtime|
        next if @options[:ignore_dirs].include?(dir.realpath)

        if !dir.directory?
          @dirs.delete dir
        elsif dir.mtime > mtime
          @dirs[dir] = dir.mtime

          if @options[:ext]
            e = '.{' + @options[:ext].join(',') + '}'
          else
            e = ''
          end
          dfiles.concat Pathname.glob(dir.to_s + "/{**/*}#{e}")
        end
      end
      dfiles.uniq.each do |file|
        if file.directory?
          dir_observe file
        else
          file_observe file, Time.at(0)
        end
      end
    end
    
    def stop
      @th.kill
    end

    def observe(files)
      Array(files).each do |file|
        file = Pathname.new(file)
        if file.directory?
          dir_observe file
        else
          next if @options[:ignore_files].include?(file.realpath)

          file_observe file
        end
      end
    end

    def file_observe(file, mtime = nil)
      if @options[:ext]
        if @options[:ext].include? file.extname.sub(/^\./, '')
          @files[file] ||= (mtime || file.mtime)
        end
      else
        @files[file] ||= (mtime || file.mtime)
      end
    end

    def dir_observe(dir)
      Find::find(dir.to_s) do |file|
        if File.directory?(file)
          dir = Pathname.new(file)
          @dirs[dir] ||= dir.mtime
        end
      end
    end
  end
end 
