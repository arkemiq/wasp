Gem::Specification.new do |s|
  s.name        = 'wasp'
  s.version     = '0.1.0'
  s.summary     = "Wasps!"
  s.description = "Wasps!"
  s.authors     = ["jhseol"]
  s.email       = 'jihoon.seol@gmail.com'
  s.files = %w[
    Gemfile
    Rakefile
    LICENSE
    README.md
    wasp.gemspec
    bin/wasp
    config/aws.yml
	  lib/wasp.rb
	  lib/wasp/wasp.rb
	  lib/wasp/nest.rb
	  lib/wasp/config.rb
	  lib/wasp/const.rb
	  lib/wasp/core_ext.rb
	  lib/wasp/ec2.rb
	  lib/wasp/queenwasp.rb
	  lib/wasp/weaponab.rb
	  report/makeplot.rb
	  test/test_wasp.rb
  ]
  s.license     = 'MIT'
  s.required_ruby_version = '>= 1.9.2'
  s.platform    = Gem::Platform::RUBY
  s.homepage    = ''
  s.add_dependency("aws-sdk", ">= 1.3.2")
  s.add_dependency("net-ssh", ">= 2.3.0")
  s.add_dependency("net-scp", ">= 1.0.4")
  s.require_paths = ['lib']
  s.bindir = 'bin'
  s.executables = ['wasp']
end