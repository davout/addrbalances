# coding: utf-8

lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'addrbalances/version'

Gem::Specification.new do |s|
  s.name        = 'addrbalances'
  s.version     = AddrBalances::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['David FRANCOIS']
  s.email       = ['david.francois@paymium.com']
  s.homepage    = 'https://paymium.com'
  s.summary     = 'Retrieve Bitcoin address histories from a local bitcoind'
  s.description = 'AddrBalances parses the blockchain in order to extract, for a collection of addresses, the operations that affect its available balance'
  s.licenses    = ['MIT']

  s.required_rubygems_version = '>= 1.3.6'

  s.add_dependency 'uuidtools', '~> 2.1'
  s.add_dependency 'oj',        '~> 2.0'
  s.add_dependency 'mysql2',    '~> 0.4.3'
  s.add_dependency 'addressable'
  s.add_dependency 'blockcypher-ruby'

  s.add_development_dependency 'pry',       '~> 0.10'
  s.add_development_dependency 'rake',      '~> 10.3'

  s.files = Dir.glob('lib/**/*') + %w(LICENSE README.md)

  s.require_path = 'lib'

  s.bindir = 'bin'
  s.executables << 'addrbalances'
end

