require 'rake/testtask'

desc "Run rspec"
task :spec do
  sh('bundle install')
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new do |t|
    t.rspec_opts = %w(-fs -c)
  end
end
task :default => :spec

Rake::TestTask.new do |t|
  t.libs << 'test'
end
