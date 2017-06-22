# Copyright (C) 2015-2017 Electronic Arts Inc.  All rights reserved.

require 'aws-sdk'
require 'base64'
require 'net/http'
require 'net/https'
require 'nokogiri'
require 'uri'

require 'awsudo'

module AWSUDO
  # I'm the abstract class for all identity providers.
  # I provide common methods for requesting a SAML assertion to an IdP
  # and for requesting with it a set of temporary keys to AWS STS.
  class IdentityProvider
    @@sts = Aws::STS::Client.new(
      credentials: Aws::Credentials.new('a', 'b', 'c'), region: 'us-east-1')

    attr_accessor :idp_login_url, :saml_provider_name
    attr_accessor :username, :password, :logger

    def sts
      @@sts
    end

    # Creates an instance of an IdentityProvider subclass
    # from the given settings
    def self.new_from_config(config, username, password)
      new(config['IDP_LOGIN_URL'], config['SAML_PROVIDER_NAME'],
               username, password)
    end

    # Initializes the instance with the given settings.
    def initialize(url, name, username, password)
      @idp_login_url = url
      @saml_provider_name = name
      @username = username
      @password = password
      @logger   = AWSUDO.logger
      begin
        URI.parse @idp_login_url
      rescue
        raise "`#{@idp_login_url.inspect}' is not a valid IDP login URL"
      end
      if @saml_provider_name.nil? || @saml_provider_name.strip.empty?
        raise "`#{@saml_provider_name.inspect}' is not a valid SAML provider name"
      end
    end

    # Builds an HTTP request object for retrieving a SAML assertion.
    # It is the subclass responsibility to define this method.
    def saml_request
      raise "should be implemented by subclass"
    end

    # Retrieves the SAML assertion from the IdP
    def get_saml_response
      req = saml_request
      res = nil
      uri = URI.parse(idp_login_url)

      loop do
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER

        res = http.request(req)
        logger.debug {"Location: <#{res['Location']}>"}
        logger.debug {"Headers: <#{res.to_hash.inspect}>"}
        logger.debug {"Body: <#{res.body.inspect}>"}

        break if res['Location'].nil?

        uri = URI.parse(res['Location'])
        req = Net::HTTP::Get.new(uri.request_uri)
        req['Cookie'] = res['Set-Cookie']
      end

      doc = Nokogiri::HTML(res.body)
      doc.xpath('/html/body//form/input[@name = "SAMLResponse"]/@value').to_s
    end

    # Retrieves a set of temporary keys from AWS STS
    def assume_role(role_arn)
      logger.debug {"role_arn: <#{role_arn}>"}
      base_arn = role_arn[/^arn:aws:iam::\d+:/]
      principal_arn = "#{base_arn}saml-provider/#{saml_provider_name}"
      logger.debug {"principal_arn: <#{principal_arn}>"}
      saml_assertion = get_saml_response
      logger.debug {"saml_assertion: <#{Base64.decode64 saml_assertion}>"}
      if saml_assertion.empty?
        raise 'Unable to get SAML assertion (failed authentication?)'
      end
      sts.assume_role_with_saml(
        role_arn: role_arn,
        principal_arn: principal_arn,
        saml_assertion: saml_assertion).credentials.to_h
    end
  end
end
