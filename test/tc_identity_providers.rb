#!/usr/bin/env ruby

$testdir = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift File.expand_path(File.join($testdir, "..", "lib"))

require 'awsudo'
require 'test/unit'

class TCAwsudoIdentityProviders < Test::Unit::TestCase
  def setup
    fixturesdir = File.join($testdir, 'fixtures')
    %w(good_configs bad_configs).each do |name|
      filenames = Dir[File.join(fixturesdir, name, '*')]
      instance_variable_set("@#{name}",
        filenames.map do |filename|
          AWSUDO.load_config(filename)
        end)
    end
  end

  def test_identity_providers_available
    assert_equal (AWSUDO::IdentityProviders.constants - [:Adfs, :Okta]), []
  end

  def test_new_identity_provider
    @bad_configs.each do |config|
      assert_raise(RuntimeError, NameError) do
        AWSUDO::IdentityProviders.new(
          config['IDP'].to_s.capitalize.to_sym, config, 'username', 'password')
      end
    end

    @good_configs.each do |config|
      assert_nothing_raised do
        AWSUDO::IdentityProviders.new(
          config['IDP'].to_s.capitalize.to_sym, config, 'username', 'password')
      end
    end
  end

  def test_state
    config = @good_configs.first
    idp = AWSUDO::IdentityProviders.new(
      config['IDP'].to_s.capitalize.to_sym, config, 'username', 'password')

    assert_equal idp.idp_login_url, config['IDP_LOGIN_URL']
    assert_equal idp.saml_provider_name, config['SAML_PROVIDER_NAME']
    assert_equal idp.username, 'username'
    assert_equal idp.password, 'password'
    assert_kind_of Aws::STS::Client, idp.sts
    assert_equal idp.logger, AWSUDO.logger
  end
end
