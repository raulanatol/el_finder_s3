require 'fileutils'
require 'pathname'

module ElFinderS3

  class Pathname
    attr_reader :root, :path, :adapter

    #
    def initialize(adapter_or_root, path = '.')
      @adapter = adapter_or_root.is_a?(ElFinderS3::Pathname) ? adapter_or_root.adapter : adapter_or_root

      @root = path.is_a?(ElFinderS3::Pathname) ? path.root : S3Pathname.new(@adapter, '/')

      if path.is_a?(ElFinderS3::Pathname)
        @path = path.path
      elsif path.is_a?(ElFinderS3::S3Pathname)
        @path = path
      else
        @path = S3Pathname.new(@adapter, path)
      end
      if absolute?
        if @path.cleanpath.to_s.start_with?(@root.to_s)
          @path = S3Pathname.new(@adapter, @path.to_s.slice((@root.to_s.length)..-1), @path.attrs)
        elsif @path.cleanpath.to_s.start_with?(@root.realpath.to_s)
          @path = S3Pathname.new(@adapter, @path.to_s.slice((@root.realpath.to_s.length)..-1), @path.attrs)
        else
          raise SecurityError, "Absolute paths are not allowed"
        end
      end
      raise SecurityError, "Paths outside the root are not allowed" if outside_of_root?

    end

    # of initialize

    def type=(value)
      @type = value
      fullpath.type = value
    end

    #
    def +(other)
      if other.is_a? ::ElFinderS3::Pathname
        other = other.path
      end
      self.class.new(@adapter, @path + other)
    end

    # of +

    #
    def is_root?
      @path.to_s == '.'
    end

    #
    def absolute?
      @path.absolute?
    end

    # of absolute?

    #
    def relative?
      @path.relative?
    end

    def exist?
      realpath.exist?
    rescue Errno::ENOENT
      false
    end

    def directory?
      realpath.directory?
    rescue Errno::ENOENT
      false
    end

    def file?
      realpath.file?
    rescue Errno::ENOENT
      false
    end


    # of relative?

    #
    def outside_of_root?
      !cleanpath.to_s.start_with?(@root.to_s)
    end

    # of outside_of_root?

    #
    def fullpath
      @fullpath ||= (@path.nil? ? @root : @root + @path)
      b = @path.nil? ? @root : @root + @path
      return @fullpath
    end

    # of fullpath

    #
    def cleanpath
      fullpath.cleanpath
    end

    # of cleanpath

    #
    def realpath
      fullpath.realpath
    end

    # of realpath

    #
    def basename(*args)
      @path.basename(*args)
    end

    # of basename

    #
    def basename_sans_extension
      @path.basename(@path.extname)
    end

    # of basename

    #
    def dirname
      self.class.new(@adapter, @path.dirname)
    end

    # of basename

    #
    def extname
      @path.nil? ? '' : @path.extname
    end

    # of extname

    #
    def to_s
      cleanpath.to_s
    end

    def to_prefix_s
      prefix_s = cleanpath.to_s
      if prefix_s == '/'
        return ''
      elsif prefix_s[0] == '/'
        prefix_s[0] = ''
      end

      if prefix_s[prefix_s.size-1] != '/'
        prefix_s = prefix_s + '/'
      end
      return prefix_s
    end

    # of to_s
    alias_method :to_str, :to_s

    #
    def child_directories(with_directory=true)
      adapter.children(self, with_directory).select { |child| child.directory? }.map { |e| self.class.new(@adapter, e) }
    end

    #
    def files(with_directory=true)
      adapter.children(self, with_directory).select { |child| child.file? }.map { |e| self.class.new(@adapter, e) }
    end


    #
    def children(with_directory=true)
      adapter.children(self, with_directory).map { |e| self.class.new(@adapter, e) }
    end

    #
    def touch(options = {})
      file2Touch = cleanpath
      self.file? ? file2Touch.type = :file : file2Touch.type = :directory
      adapter.touch(file2Touch, options)
    end

    #
    def relative_to(other)
      @path.relative_path_from(other)
    end

    #
    def unique
      return self.dup unless fullpath.file?
      copy = 1
      begin
        new_file = self.class.new(@adapter, dirname + "#{basename_sans_extension} #{copy}#{extname}")
        copy += 1
      end while new_file.exist?
      new_file
    end

    # of unique

    #
    def duplicate
      _basename = basename_sans_extension
      copy = 1
      if _basename.to_s =~ /^(.*) copy (\d+)$/
        _basename = $1
        copy = $2.to_i
      end
      begin
        new_file = self.class.new(@adapter, dirname + "#{_basename} copy #{copy}#{extname}")
        copy += 1
      end while new_file.exist?
      new_file
    end

    # of duplicate

    #
    def rename(to)
      to = self.class.new(@adapter, to)
      realpath.rename(to.fullpath.to_s)
      to
    end

    # of rename

    {
      'ftype' => {:path => 'realpath', },
      'mkdir' => {:path => 'fullpath', :args => '(*args)'},
      'mtime' => {:path => 'realpath', },
      'open' => {:path => 'fullpath', :args => '(*args, &block)'},
      'read' => {:path => 'fullpath', :args => '(*args)'},
      'write' => {:path => 'fullpath', :args => '(*args)'},
      'readlink' => {:path => 'fullpath', },
      'readable?' => {:path => 'realpath', :rescue => true},
      'size' => {:path => 'realpath', },
      'symlink?' => {:path => 'fullpath', },
      'unlink' => {:path => 'realpath', },
      'writable?' => {:path => 'realpath', :rescue => true},
    }.each_pair do |meth, opts|
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{meth}#{opts[:args]}
      #{opts[:path]}.#{meth}#{opts[:args]}
      #{"rescue Errno::ENOENT\nfalse" if opts[:rescue]}
        end
      METHOD
    end


  end # of class Pathname

end # of module ElFinderS3
