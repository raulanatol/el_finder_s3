module ElFinderS3
  require 'cache'

  class DummyCacheClient
    def get
      nil
    end

    def set
      nil
    end

    def delete
      nil
    end
  end

  class CacheConnector

    def initialize(client)
      @cache = Cache.wrap(client)
    end

    def cache_hash(operation, pathname)
      Base64.urlsafe_encode64("#{operation}::#{pathname}").chomp.tr("=\n", "")
    end

    def cached(operation, pathname)
      cache_hash_key = cache_hash(operation, pathname)
      response = @cache.get(cache_hash_key)
      unless response.nil?
        return response
      end

      response = yield

      @cache.set(cache_hash_key, response)

      response
    end

    def clear_cache(pathname)
      ElFinderS3::Operations.each do |operation|
        @cache.delete cache_hash(operation, pathname)
      end
    end
  end
end
