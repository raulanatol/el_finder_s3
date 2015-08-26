require 'net/ftp/list'

module ElFinderS3
  class FtpAdapter
    attr_reader :connection, :server

    def initialize(server)
      @server = {
        response_cache_expiry_seconds: 30,
        passive: false,
      }.merge(server)

      @cached_responses = {}
    end

    def connect
      unless connected?
        ElFinderS3::Connector.logger.info "  \e[1;32mFTP:\e[0m  Connecting to #{server[:host]} as #{server[:username]}"
        @connection = Net::FTP.new( server[:host], server[:username], server[:password] )
        @connection.passive = server[:passive]
      end

      @connection
    end

    def close
      if connected?
        ElFinderS3::Connector.logger.info "  \e[1;32mFTP:\e[0m  Closing connection to #{server[:host]}"
        @connection.close
      end
    end

    def connected?
      self.connection && !self.connection.closed?
    end

    def children(pathname, with_directory)
      cached :children, pathname do
        ftp_context do
          ElFinderS3::Connector.logger.debug "  \e[1;32mFTP:\e[0m    Fetching children of #{pathname}"
          list("-la", pathname).map { |e|
            entry = Net::FTP::List.parse(e)

            # Skip . and .. entries
            next if entry.basename =~ /^\.+$/
            # ElFinderS3::Connector.logger.debug "  \e[1;32mFTP:\e[0m      Seeing #{e}"

            if with_directory
              pathname.fullpath + ::ElFinderS3::S3Pathname.new(self, entry)
            else
              ::ElFinderS3::S3Pathname.new(self, entry)
            end
          }.compact
        end
      end
    end

    def touch(pathname, options={})
      unless exist?(pathname)
        ftp_context do
          ElFinderS3::Connector.logger.debug "  \e[1;32mFTP:\e[0m    Touching #{pathname}"
          empty_file = StringIO.new("")
          # File does not exist, create
          begin
            storlines("STOR #{pathname}", empty_file)
          ensure
            empty_file.close
          end
        end
        clear_cache(pathname)
      end
      true
    end

    def exist?(pathname)
      cached :exist?, pathname do
        ftp_context do
          ElFinderS3::Connector.logger.debug "  \e[1;32mFTP:\e[0m    Testing existence of #{pathname}"
          begin
            # Test if the file exists
            size(pathname.to_s)
            true
          rescue Net::FTPPermError => ex
            # Can't "size" directories, but the error returned is different than if the file
            # doesn't exist at all
            if ex.message.match /(?:The system cannot find the file specified|Could not get file size)/
              false
            else
              true
            end
          end
        end
      end
    end

    def path_type(pathname)
      cached :path_type, pathname do
        ftp_context do
          ElFinderS3::Connector.logger.debug "  \e[1;32mFTP:\e[0m    Getting type of #{pathname}"
          begin
            chdir(pathname.to_s)
            :directory
          rescue Net::FTPPermError => e
            :file
          end
        end
      end
    end

    def size(pathname)
      cached :size, pathname do
        ftp_context do
          ElFinderS3::Connector.logger.debug "  \e[1;32mFTP:\e[0m    Getting size of #{pathname}"
          begin
            size(pathname.to_s)
          rescue Net::FTPPermError => e
            nil
          rescue Net::FTPReplyError => e
            nil
          end
        end
      end
    end

    def mtime(pathname)
      cached :mtime, pathname do
        ftp_context do
          ElFinderS3::Connector.logger.debug "  \e[1;32mFTP:\e[0m    Getting modified time of #{pathname}"
          begin
            mtime(pathname.to_s)
          rescue Net::FTPPermError => e
            # This command doesn't work on directories
            0
          end
        end
      end
    end

    def rename(pathname, new_name)
      ftp_context do
        ElFinderS3::Connector.logger.debug "  \e[1;32mFTP:\e[0m    Renaming #{pathname} to #{new_name}"
        rename(pathname.to_s, new_name.to_s)
      end
      clear_cache(pathname)
    end

    ##
    # Both rename and move perform an FTP RNFR/RNTO (rename).  Move differs because
    # it first changes to the parent of the source pathname and uses a relative path for
    # the RNFR.  This seems to allow the (Microsoft) FTP server to rename a directory
    # into another directory (e.g. /subdir/target -> /target )
    def move(pathname, new_name)
      ftp_context(pathname.dirname) do
        ElFinderS3::Connector.logger.debug "  \e[1;32mFTP:\e[0m    Moving #{pathname} to #{new_name}"
        rename(pathname.basename.to_s, new_name.to_s)
      end
      clear_cache(pathname)
      clear_cache(new_name)
    end

    def mkdir(pathname)
      ftp_context do
        ElFinderS3::Connector.logger.debug "  \e[1;32mFTP:\e[0m    Creating directory #{pathname}"
        mkdir(pathname.to_s)
      end
      clear_cache(pathname)
    end

    def rmdir(pathname)
      ftp_context do
        ElFinderS3::Connector.logger.debug "  \e[1;32mFTP:\e[0m    Removing directory #{pathname}"
        rmdir(pathname.to_s)
      end
      clear_cache(pathname)
    end

    def delete(pathname)
      ftp_context do
        ElFinderS3::Connector.logger.debug "  \e[1;32mFTP:\e[0m    Deleting #{pathname}"
        if pathname.directory?
          rmdir(pathname.to_s)
        else
          delete(pathname.to_s)
        end
      end
      clear_cache(pathname)
    end

    def retrieve(pathname)
      ftp_context do
        ElFinderS3::Connector.logger.debug "  \e[1;32mFTP:\e[0m    Retrieving #{pathname}"
        content = StringIO.new()
        begin
          retrbinary("RETR #{pathname}", 10240) do |block|
            content << block
          end
          content.string
        ensure
          content.close
        end
      end
    end

    def store(pathname, content)
      ftp_context do
        ElFinderS3::Connector.logger.debug "  \e[1;32mFTP:\e[0m    Storing #{pathname}"
        # If content is a string, wrap it in a StringIO
        content = StringIO.new(content) if content.is_a? String
        begin
          storbinary("STOR #{pathname}", content, 10240)
        ensure
          content.close if content.respond_to?(:close)
        end
      end
      clear_cache(pathname)
    end

    private

    ##
    # Creates an FTP connection, if necessary, and executes the given block
    # in the context of that connection.  If a pathname is provided, it is
    # used to set the current working directory first
    def ftp_context(pathname = nil, &block)
      begin
        connect

        self.connection.chdir(pathname) unless pathname.nil?

        self.connection.instance_eval &block
      rescue Net::FTPPermError => ex
        if ex.message =~ /(?:User cannot log in|Login incorrect)/
          ElFinderS3::Connector.logger.info "  \e[1;32mFTP:\e[0m    Authentication required: #{ex}"
          raise FtpAuthenticationError.new(ex.message)
        else
          ElFinderS3::Connector.logger.error "  \e[1;32mFTP:\e[0m    Operation failed with error #{ex}"
          raise
        end
      rescue Net::FTPReplyError => ex
        if ex.message =~ /(?:Password required|Login incorrect)/
          ElFinderS3::Connector.logger.info "  \e[1;32mFTP:\e[0m    Authentication required: #{ex}"
          raise FtpAuthenticationError.new(ex.message)
        else
          ElFinderS3::Connector.logger.error "  \e[1;32mFTP:\e[0m    Operation failed with error #{ex}"
          raise
        end
      end
    end

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

        max_staleness = Time.now - @server[:response_cache_expiry_seconds]

        if response[:timestamp] < max_staleness
          @cached_responses[pathname.to_s].delete(operation)
          nil
        else
          response[:response]
        end
      end
    end
  end
end
