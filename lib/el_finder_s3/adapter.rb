module ElFinderS3
  class Adapter
    attr_reader :connection, :server, :s3_connector

    def initialize(server)
      @server = {
        response_cache_expiry_seconds: 3000
      }
      @cached_responses = {}
      @s3_connector = ElFinderS3::S3Connector.new server
    end

    def connect
      @connection
    end

    def close
      true
    end

    def children(pathname, with_directory)
      cached :children, pathname do
        @s3_connector.ls_la(pathname, with_directory)
      end
    end

    def touch(pathname, options={})
      @s3_connector.touch(pathname.to_file_prefix_s)
    end

    def exist?(pathname)
      cached :exist?, pathname do
        @s3_connector.exist? pathname
      end
    end

    # @param [ElFinderS3::Pathname] pathname
    def path_type(pathname)
      cached :path_type, pathname do
        result = :directory
        begin
          if pathname.to_s == '/'
            result = :directory
          end
        rescue
          result = pathname[:type]
        end
        return result
      end
    end

    def size(pathname)
      #FIXME
      # cached :size, pathname do
      #   ftp_context do
      #     ElFinderS3::Connector.logger.debug "  \e[1;32mFTP:\e[0m    Getting size of #{pathname}"
      #     begin
      #       size(pathname.to_s)
      #     rescue Net::FTPPermError => e
      #       nil
      #     rescue Net::FTPReplyError => e
      #       nil
      #     end
      #   end
      # end
    end

    #FIXME
    def mtime(pathname)
      cached :mtime, pathname do
        # ftp_context do
        #   ElFinderS3::Connector.logger.debug "  \e[1;32mFTP:\e[0m    Getting modified time of #{pathname}"
        #   begin
        #     mtime(pathname.to_s)
        #   rescue Net::FTPPermError => e
        # This command doesn't work on directories
        0
        # end
        # end
      end
    end

    #FIXME
    def rename(pathname, new_name)
      # ftp_context do
      #   ElFinderS3::Connector.logger.debug "  \e[1;32mFTP:\e[0m    Renaming #{pathname} to #{new_name}"
      #   rename(pathname.to_s, new_name.to_s)
      # end
      # clear_cache(pathname)
    end

    ##
    # Both rename and move perform an FTP RNFR/RNTO (rename).  Move differs because
    # it first changes to the parent of the source pathname and uses a relative path for
    # the RNFR.  This seems to allow the (Microsoft) FTP server to rename a directory
    # into another directory (e.g. /subdir/target -> /target )
    def move(pathname, new_name)
      #FIXME
      # ftp_context(pathname.dirname) do
      #   ElFinderS3::Connector.logger.debug "  \e[1;32mFTP:\e[0m    Moving #{pathname} to #{new_name}"
      #   rename(pathname.basename.to_s, new_name.to_s)
      # end
      # clear_cache(pathname)
      # clear_cache(new_name)
    end

    def mkdir(pathname)
      if @s3_connector.mkdir(pathname.to_prefix_s)
        #FIXME review cache clear
        # clear_cache(pathname)
        true
      else
        false
      end
    end

    def rmdir(pathname)
      #FIXME
      # ftp_context do
      #   ElFinderS3::Connector.logger.debug "  \e[1;32mFTP:\e[0m    Removing directory #{pathname}"
      #   rmdir(pathname.to_s)
      # end
      # clear_cache(pathname)
    end

    def delete(pathname)
      #FIXME
      # ftp_context do
      #   ElFinderS3::Connector.logger.debug "  \e[1;32mFTP:\e[0m    Deleting #{pathname}"
      #   if pathname.directory?
      #     rmdir(pathname.to_s)
      #   else
      #     delete(pathname.to_s)
      #   end
      # end
      # clear_cache(pathname)
    end

    def retrieve(pathname)
      #FIXME
      # ftp_context do
      #   ElFinderS3::Connector.logger.debug "  \e[1;32mFTP:\e[0m    Retrieving #{pathname}"
      #   content = StringIO.new()
      #   begin
      #     retrbinary("RETR #{pathname}", 10240) do |block|
      #       content << block
      #     end
      #     content.string
      #   ensure
      #     content.close
      #   end
      # end
    end

    def store(pathname, content)
      #FIXME
      # ftp_context do
      #   ElFinderS3::Connector.logger.debug "  \e[1;32mFTP:\e[0m    Storing #{pathname}"
      #   If content is a string, wrap it in a StringIO
      # content = StringIO.new(content) if content.is_a? String
      # begin
      #   storbinary("STOR #{pathname}", content, 10240)
      # ensure
      #   content.close if content.respond_to?(:close)
      # end
      # end
      # clear_cache(pathname)
    end

    private

    ##
    # Remove all entries for the given pathname (and its parent folder)
    # from the FTP cache
    def clear_cache(pathname)
      @cached_responses.delete(pathname.to_s)

      if pathname.to_s != '/' && pathname.to_s != '.'
        # Clear parent of this entry, too
        @cached_responses.delete(pathname.dirname.to_s)
      end
    end

    ##
    # Looks in the cache for an entry for the given pathname and operation,
    # returning the cached result if one is found.  If one is not found, the given
    # block is invoked and its result is stored in the cache and returned
    #
    # The FTP cache is used to prevent redundant FTP queries for information such as a
    # file's size, or a directory's contents, during a *single* FTP session.
    def cached(operation, pathname)
      response = cache_get(operation, pathname)
      unless response.nil?
        return response
      end

      response = yield
      cache_put operation, pathname, response

      response
    end

    ##
    # Store an FTP response in the cache
    def cache_put(operation, pathname, response)
      @cached_responses[pathname.to_s] = {} unless @cached_responses.include?(pathname.to_s)

      @cached_responses[pathname.to_s][operation] = {
        timestamp: Time.now,
        response: response
      }
    end

    ##
    # Fetch an FTP response from the cache
    def cache_get(operation, pathname)
      if @cached_responses.include?(pathname.to_s) && @cached_responses[pathname.to_s].include?(operation)
        response = @cached_responses[pathname.to_s][operation]

        #FIXME cache timeout
        # max_staleness = Time.now - @server[:response_cache_expiry_seconds]

        # if response[:timestamp] < max_staleness
        #   @cached_responses[pathname.to_s].delete(operation)
        #   nil
        # else
        response[:response]
        # end
      end
    end
  end
end
