module ElFinderS3
  module Action
    class << self
      def included(klass)
        klass.send(:extend, ElFinderS3::ActionClass)
      end
    end
  end

  module ActionClass
    def el_finder_ftp(name = :elfinder, &block)
      self.send(:define_method, name) do
        h, r = ElFinderS3::Connector.new(instance_eval(&block)).run(params)
        headers.merge!(h)
        if r.include?(:file_data)
          send_data r[:file_data], type: r[:mime_type], disposition: r[:disposition], filename: r[:filename]
        else
          if browser.ie8? || browser.ie9?
            # IE 8 and IE 9 don't accept application/json as a response to a POST in some cases:
            # http://blog.degree.no/2012/09/jquery-json-ie8ie9-treats-response-as-downloadable-file/
            # so we send text/html instead
            response = (r.empty? ? {:nothing => true} : {:text => r.to_json})
          else
            response = (r.empty? ? {:nothing => true} : {:json => r})
          end

          render response, :layout => false
        end
      end
    end
  end
end
