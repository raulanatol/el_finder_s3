module ElFinderS3
  require 'cache'
  class CacheConnector

    def initialize(client = nil)
      @cache = client.nil? ? ElFinderS3::DummyCacheClient.new : Cache.wrap(client)
    end

    def cache_hash(operation, pathname)
      Base64.urlsafe_encode64("#{operation}::#{pathname}").chomp.tr("=\n", "")
    end

    def cached(operation, pathname)
      cache_hash_key = cache_hash(operation, pathname)
      if @cache.exist? cache_hash_key
        return @cache.get(cache_hash_key)
      else
        response = yield

        @cache.set(cache_hash_key, response, 2.years)

        response
      end
    end

    def clear_cache(pathname, recursive = true)
      ElFinderS3::Operations.each do |operation|
        @cache.delete cache_hash(operation, pathname)
      end

      if recursive || pathname.file?
        pathname_str = pathname.to_s
        if pathname_str != '/' && pathname_str != '.'
          clear_cache(pathname.dirname, recursive)
        end
      end
    end
  end
end
