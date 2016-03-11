PKG_NAME = 'awsudo'
PKG_VERSION = '1.0.2'
PKG_FILES = Dir['bin/*'] + ['lib/awsudo.rb'] + %w{LICENSE CHANGELOG.md CONTRIBUTING.md README.md}

spec = Gem::Specification.new do |s|
  s.name = PKG_NAME
  s.version = PKG_VERSION
  s.summary = 'executes a command with the permissions given by an AWS IAM role'
  s.description = <<-EOS
awsudo enables users to execute commands that make API calls to AWS under the
security context of an IAM role. The IAM role is assumed only upon successful
authentication against a SAML compliant federation service.

aws-agent enables users to authenticate against a SAML compliant federation
service once, after which aws-agent provides temporary credentials to awsudo to
use.
  EOS
  s.files = PKG_FILES
  s.add_runtime_dependency 'aws-sdk', '~> 2'
  s.require_path = 'lib'
  s.executables << 'awsudo' << 'aws-agent'
  s.author = 'Gerardo Santana Gomez Garrido'
  s.email = 'gsantana@ea.com'
  s.homepage = 'https://github.com/electronicarts/awsudo'
end
