module ElFinderS3
  # No cache client
  class DummyCacheClient
    def get(key)
      nil
    end

    def set(key, value, ttl = 24.hours)
      nil
    end

    def delete(key)
      nil
    end

    def exist?(key)
      false
    end
  end
end
