require 'pathname'
require 'find'
require 'logger'

module Rascut
  class FileObserver
    DEFAULT_OPTIONS = {
      :interval => 1,
      :ignore_files => [],
      :ignore_dirs => [/\/.svn/],
      :logger => Logger.new(STDOUT),
      :dir_counter => 5,
      :ext => nil
    }

    MSWIN32 = !!RUBY_PLATFORM.include?('mswin32')

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
    attr_reader :files, :dirs

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

    private

    def update_check
      update_files = []
      check_dirs if check_dir?

      @files.each do |file, mtime|
        if !file.readable?
          @files.delete file
        elsif file.mtime > mtime
          @files[file] = file.mtime
          update_files << file
        end
      end

      unless update_files.empty?
        logger.info 'Found update file(s)' + update_files.map{|f| f.to_s}.inspect
        @update_handlers.each do |handler|
          if handler.arity == 1
            handler.call update_files
          else
            handler.call
          end
        end
      end
    end

    def check_dir?
      @check_dir_count ||= options[:dir_counter]
      if @check_dir_count > options[:dir_counter]
        @check_dir_count = 0
      else
        @check_dir_count += 1
      end
      @check_dir_count.zero?
    end

    def check_dirs
      dfiles = []
      @dirs.each do |dir, mtime|
        begin
          rp = dir.realpath.to_s
        rescue Errno::EINVAL
          rp = dir.realpath(false).to_s
          rp.sub!(/^\//, '') if mswin32? # XXX for mswin32 ruby 1.8.4
        end

        next if @options[:ignore_dirs].include?(rp)

        if !dir.directory?
          @dirs.delete dir
        elsif dir.to_s.match %r{/\.svn|/CVS}
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
          #@dirs[dir] ||= dir.mtie
          @dirs[dir] ||= Time.at(0) # XXX for win32 ruby(filesystem?)?
        end
      end
    end

    def mswin32?
      MSWIN32
    end
  end
end 
