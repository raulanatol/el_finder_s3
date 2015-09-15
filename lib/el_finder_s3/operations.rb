module ElFinderS3
  class Operations
    include Enumerable

    PATH_TYPE = :path_type
    EXIST = :exist
    CHILDREN = :children
    MTIME = :mtime

    def self.each
      yield PATH_TYPE
      yield EXIST
      yield CHILDREN
      yield MTIME
    end

  end
end
