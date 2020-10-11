lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'f4r'

Gem::Specification.new do |spec|
  spec.name          = 'f4r'
  spec.version       = F4R::VERSION
  spec.authors       = ['jpablobr']
  spec.email         = ['xjpablobrx@gmail.com']
  spec.homepage      = 'https://github.com/jpablobr/f4r'
  spec.summary       = 'Simple .FIT file encoder/decoder'
  spec.license       = 'MIT'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = spec.homepage

  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.require_paths = ['lib']

  spec.add_dependency 'bindata', '2.4.4'
  spec.add_dependency 'csv', '3.1.2'
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 12.3.3'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'minitest-autotest', '~> 1.1.1'
  spec.add_development_dependency 'minitest-line', '~> 0.6.5'
  spec.add_development_dependency 'pry', '~> 0.12'
end
