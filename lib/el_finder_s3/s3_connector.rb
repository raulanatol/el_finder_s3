require 'aws-sdk'

module ElFinderS3
  class S3Connector
    :s3_client
    :bucket_name

    def initialize(server)
      raise(ArgumentError, 'Missing required :region option') unless server.key?(:region)
      raise(ArgumentError, 'Missing required :access_key_id option') unless server.key?(:access_key_id)
      raise(ArgumentError, 'Missing required :secret_access_key option') unless server.key?(:secret_access_key)
      raise(ArgumentError, 'Missing required :bucket_name option') unless server.key?(:bucket_name)
      Aws.config.update(
        {
          region: server[:region],
          credentials: Aws::Credentials.new(server[:access_key_id], server[:secret_access_key])
        }
      )
      @bucket_name = server[:bucket_name]
      @s3_client = Aws::S3::Client.new
    end

    # @param [ElFinderS3::Pathname] pathname
    def ls_la(pathname, with_directory)
      prefix = pathname.to_prefix_s
      query = {
        bucket: @bucket_name,
        delimiter: '/',
        encoding_type: 'url',
        max_keys: 100,
        prefix: prefix
      }

      response = @s3_client.list_objects(query)
      result = []
      #Files
      response.contents.each { |e|
        if e.key != prefix
          if with_directory
            result.push(pathname.fullpath + ::ElFinderS3::S3Pathname.new(self, e))
          else
            e.key = e.key.gsub(prefix, '')
            result.push(::ElFinderS3::S3Pathname.new(self, e))
          end
        end
      }
      #Folders
      response.common_prefixes.each { |f|
        if f.prefix != '' && f.prefix != prefix && f.prefix != '/'
          f.prefix = f.prefix.split('/').last
          result.push(pathname.fullpath + ::ElFinderS3::S3Pathname.new(self, f))
        end
      }
      return result
    end

    # @param [ElFinderS3::Pathname] pathname
    def exist?(pathname)
      query = {
        bucket: @bucket_name,
        key: pathname.to_prefix_s
      }
      begin
        @s3_client.head_object(query)
        true
      rescue Aws::S3::Errors::NotFound
        false
      end
    end

    def mkdir(folder_name)
      begin
        @s3_client.put_object(bucket: @bucket_name, key: folder_name)
        true
      rescue
        false
      end
    end

    def touch(filename)
      begin
        @s3_client.put_object(bucket: @bucket_name, key: filename)
        true
      rescue
        false
      end
    end

    def store(filename, content)
      @s3_client.put_object(bucket: @bucket_name, key: filename, body: content)
    end
  end
end
