# -*- encoding: utf-8 -*-
require File.expand_path('../lib/keyspace/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Tony Arcieri"]
  gem.email         = ["tony.arcieri@gmail.com"]
  gem.description   = "A capability-based key management/credential management system"
  gem.summary       = "Keyspace provides end-to-end authentication and confidentiality of keys and other secure data"
  gem.homepage      = ""

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "keyspace"
  gem.require_paths = ["lib"]
  gem.version       = Keyspace::VERSION

  gem.add_runtime_dependency 'rbnacl',  '~> 1.0.0'
  gem.add_runtime_dependency 'base32',  '~> 0.2.0'
  gem.add_runtime_dependency 'sinatra', '~> 1.3.5'
  gem.add_runtime_dependency 'rack',    '~> 1.5.2'
  gem.add_runtime_dependency 'thor',    '~> 0.17.0'
  gem.add_runtime_dependency 'redis',   '~> 3.0.3'

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'rack-test'
end
