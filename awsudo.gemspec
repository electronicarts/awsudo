spec = Gem::Specification.new do |s|
  s.name = 'awsudo'
  s.version = '2.0.0'
  s.license = 'BSD-3-Clause'
  s.summary = 'executes a command with the permissions given by an AWS IAM role'
  s.description = <<-EOS
awsudo enables users to execute commands that make API calls to AWS under the
security context of an IAM role. The IAM role is assumed only upon successful
authentication against a SAML compliant federation service.

aws-agent enables users to authenticate against a SAML compliant federation
service once, after which aws-agent provides temporary credentials to awsudo to
use.
  EOS
  s.files = Dir['bin/*'] + ['lib/awsudo.rb'] + Dir['lib/awsudo/*.rb'] +
            Dir['lib/awsudo/identity_providers/*.rb'] +
            %w{LICENSE CHANGELOG.md CONTRIBUTING.md README.md}
  s.add_runtime_dependency 'aws-sdk', '~> 2'
  s.add_runtime_dependency 'nokogiri', '~> 1.7'
  s.require_path = 'lib'
  s.executables << 'awsudo' << 'aws-agent'
  s.author = 'Gerardo Santana Gomez Garrido'
  s.email = 'gsantana@ea.com'
  s.homepage = 'https://github.com/electronicarts/awsudo'
end
