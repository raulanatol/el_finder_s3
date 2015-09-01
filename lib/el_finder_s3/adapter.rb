module ElFinderS3
  require 'memcached'
  require 'cache'

  class Adapter
    attr_reader :server, :s3_connector

    def initialize(server, cache_connector)
      @server = {
        response_cache_expiry_seconds: 3000
      }
      @cached_responses = {}
      @s3_connector = ElFinderS3::S3Connector.new server
      if cache_connector.nil?
        @cache_connector = ElFinderS3::CacheConnector.new(ElFinderS3::DummyCacheClient.new)
      else
        @cache_connector = cache_connector
      end

      # client = Memcached.new('127.0.0.1:11211', :binary_protocol => true)
      # @cache = Cache.wrap(client)
    end

    def close
      true
    end

    def children(pathname, with_directory)
      elements = @cache_connector.cached ElFinderS3::Operations::CHILDREN, pathname do
        @s3_connector.ls_la(pathname)
      end

      result = []
      elements[:folders].each { |folder|
        result.push(pathname.fullpath + ElFinderS3::S3Pathname.new(@s3_connector, folder, {:type => :directory}))
      }
      elements[:files].each { |file|
        if with_directory
          result.push(pathname.fullpath + ElFinderS3::S3Pathname.new(@s3_connector, file, {:type => :file}))
        else
          result.push(ElFinderS3::S3Pathname.new(@s3_connector, file, {:type => :file}))
        end
      }
      result
    end

    def touch(pathname, options={})
      @s3_connector.touch(pathname.to_file_prefix_s)
    end

    def exist?(pathname)
      @cache_connector.cached :exist?, pathname do
        @s3_connector.exist? pathname
      end
    end

    # @param [ElFinderS3::Pathname] pathname
    def path_type(pathname)
      @cache_connector.cached :path_type, pathname do
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
      # @cache_connector.cached :size, pathname do
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
      @cache_connector.cached :mtime, pathname do
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
      @s3_connector.get(pathname.to_file_prefix_s)
    end

    def store(pathname, content)
      @s3_connector.store(pathname.to_file_prefix_s, content)
      #TODO clear_cache(pathname)
    end
  end
end
