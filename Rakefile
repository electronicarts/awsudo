task :default => :test

desc "Test unit"
task :test do
  system 'test/tc_resolve_role.rb'
end

desc "Build gem"
task :gem do
  system 'gem build eawsudo.gemspec'
end
