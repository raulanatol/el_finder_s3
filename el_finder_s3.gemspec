# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'el_finder_s3/version'

Gem::Specification.new do |spec|
  spec.name = 'el_finder_s3'
  spec.version = ElFinderS3::VERSION
  spec.authors = ['Raúl Anatol']
  spec.email = ['raul@natol.es']

  spec.summary = %q{elFinder server side connector for Ruby, with an S3 aws service.}
  spec.description = %q{Ruby gem to provide server side connector to elFinder using AWS S3 like a container}
  spec.homepage = 'https://github.com/raulanatol/el_finder_s3'
  spec.license = 'MIT'

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise 'RubyGems 2.0 or newer is required to protect against public gem pushes.'
  end

  spec.files = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency('aws-sdk', '~> 2')
  #FIXME remove after testing
  spec.add_dependency('net-ftp-list', '~> 3.2')

  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'rake', '~> 10.0'
end
