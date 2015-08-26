module ElFinderS3
  class Railties < ::Rails::Railtie
    initializer 'Rails logger' do
      ElFinderS3::Connector.logger = Rails.logger
    end
  end
end
