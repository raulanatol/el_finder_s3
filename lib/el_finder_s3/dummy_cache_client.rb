module ElFinderS3
  # No cache client
  class DummyCacheClient
    def get(key)
      nil
    end

    def set(key, value)
      nil
    end

    def delete(key)
      nil
    end
  end
end
