require 'rake/testtask'
require 'rubygems/package'

task :default => :test

desc "Test unit"
task :test do
  load 'test/test_suite.rb'
end

desc "Build gem"
task :gem do
  spec = Gem::Specification.load('awsudo.gemspec')
  Gem::Package.build spec
end
