# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'fix/engine/version'

Gem::Specification.new do |s|
  s.name        = 'fix-engine'
  s.version     = Fix::Engine::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['David François']
  s.email       = ['david.francois@paymium.com']
  s.homepage    = 'https://github.com/paymium/fix-engine'
  s.summary     = 'FIX engine handling connections, sessions, and message callbacks'
  s.description = <<-EOS
  The FIX engine library allows one to easily connect to a FIX acceptor and establish
  a session, it will handle the administrative messages such as logons, hearbeats, gap fills and
  allow custom handling of business level messages.

  Likewise, an acceptor may be easily implemented by defining callbacks for business level messages.

  FIX protocol message parsing capabilities are provided by the fix-protocol gem, which
  currently supports the administrative subset (and a few business level messages) of the FIX 4.4
  message specification. 
  EOS

  s.required_rubygems_version = '>= 1.3.6'

  s.add_development_dependency 'rspec',     '~> 3.1'
  s.add_development_dependency 'rake',      '~> 10.3'
  s.add_development_dependency 'yard',      '~> 0.8'
  s.add_development_dependency 'redcarpet', '~> 3.1'
  s.add_development_dependency 'simplecov', '~> 0.9'
  s.add_development_dependency 'coveralls', '~> 0.7'

  s.add_dependency 'fix-protocol', '~> 0.0.64'
  s.add_dependency 'eventmachine', '~> 1.0'

  s.licenses      = ['MIT']

  s.files         = Dir.glob('{lib,bin}/**/*') + %w(LICENSE README.md)
  s.require_path  = 'lib'
  s.bindir        = 'bin'
end
