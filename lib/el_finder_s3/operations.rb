module ElFinderS3
  class Operations
    include Enumerable

    PATH_TYPE = :path_type
    EXIST = :exist
    CHILDREN = :children

    def each
      yield PATH_TYPE
      yield EXIST
      yield CHILDREN
    end

  end
end
