module ElFinderS3
  class S3Pathname < Pathname
    attr_reader :adapter

    def initialize(adapter, list_entry_or_name, attrs = {})
      @adapter = adapter

      if list_entry_or_name.is_a? ElFinderS3::S3Pathname
        super(list_entry_or_name.to_s)
        self.attrs = list_entry_or_name.attrs
      elsif list_entry_or_name.is_a? Aws::S3::Types::Object
        super(list_entry_or_name[:key])
        @size = list_entry_or_name[:size]
        @type = :file
      elsif list_entry_or_name.is_a? Aws::S3::Types::CommonPrefix
        name = list_entry_or_name[:prefix]
        super(name)
        @size = 0
        @type = :directory
      else
        super(list_entry_or_name)
        self.attrs = attrs
      end
    end

    def +(other)
      other = S3Pathname.new(adapter, other) unless S3Pathname === other
      S3Pathname.new(adapter, plus(@path, other.to_s), other.attrs)
    end

    def attrs
      {
        type: @type,
        time: @time,
        size: @size
      }
    end

    def attrs=(val)
      @time = val[:time]
      @type = val[:type]
      @size = val[:size]
    end

    def atime
      mtime
    end

    def ctime
      mtime
    end

    def mtime
      @time ||= adapter.mtime(self)
    end

    def cleanpath
      self
    end

    def exist?
      adapter.exist?(self)
    end

    def directory?
      type == :directory
    end

    def readable?
      true
    end

    def writable?
      true
    end

    def symlink?
      false
    end

    def file?
      type == :file
    end

    def realpath
      self
    end

    def ftype
      type.to_s
    end

    def type
      @type ||= adapter.path_type(self)
    end

    def type=(value)
      @type = value
    end

    def size
      unless @type == :directory
        @size ||= adapter.size(self)
      end
    end

    def touch
      adapter.touch(self)
    end

    def rename(to)
      adapter.rename(self, to)
    end

    def mkdir
      adapter.mkdir(self)
      @type = :directory
      @size = 0
    end

    def rmdir
      adapter.rmdir(self)
    end

    def unlink
      adapter.delete(self)
    end

    def read
      adapter.retrieve(self)
    end

    def write(content)
      adapter.store(self, content)
      @size = nil
    end

    def executable?
      false
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
      prefix_s
    end

    def to_file_prefix_s
      result = to_prefix_s
      result[-1] = '' unless result[-1] != '/'
      result
    end

    def pipe?
      false
    end

    # These methods are part of the base class, but need to be handled specially
    # since they return new instances of this class
    # The code below unwraps the pathname, invokces the original method on it,
    # and then wraps the result into a new, properly constructed instance of this class
    {
      'dirname' => {:args => '(*args)'},
      'basename' => {:args => '(*args)'},
      'cleanpath' => {:args => '(*args)'},
    }.each_pair do |meth, opts|
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{meth}#{opts[:args]}
          v = ::Pathname.new(self.to_s).#{meth}#{opts[:args]}
          self.class.new(@adapter, v.to_s)
        end
      METHOD
    end
  end
end
