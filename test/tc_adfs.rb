#!/usr/bin/env ruby

$testdir = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift File.expand_path(File.join($testdir, "..", "lib"))

require 'awsudo'
require 'test/unit'

class TCAwsudoAdfs < Test::Unit::TestCase
  def setup
    fixturesdir = File.join($testdir, 'fixtures', 'adfs')
    %w(good_configs bad_configs).each do |name|
      filenames = Dir[File.join(fixturesdir, name, '*')]
      instance_variable_set("@#{name}",
        filenames.map do |filename|
          AWSUDO.load_config(filename)
        end)
    end
  end

  def test_new_identity_provider
    @bad_configs.each do |config|
      assert_raise(RuntimeError) do
        AWSUDO::IdentityProviders::Adfs.new(
          config['IDP_LOGIN_URL'], config['SAML_PROVIDER_NAME'],
          'username', 'password')
      end
    end

    @good_configs.each do |config|
      assert_nothing_raised do
        AWSUDO::IdentityProviders::Adfs.new(
          config['IDP_LOGIN_URL'], config['SAML_PROVIDER_NAME'],
          'username', 'password')
      end
    end
  end

  def test_state
    config = @good_configs.first
    idp = AWSUDO::IdentityProviders::Adfs.new(
      config['IDP_LOGIN_URL'], config['SAML_PROVIDER_NAME'],
      'username', 'password')

    assert_equal idp.idp_login_url, config['IDP_LOGIN_URL']
    assert_equal idp.saml_provider_name, config['SAML_PROVIDER_NAME']
    assert_equal idp.username, 'username'
    assert_equal idp.password, 'password'
    assert_equal idp.logger, AWSUDO.logger
  end
end
