# Copyright (C) 2015-2017 Electronic Arts Inc.  All rights reserved.

require 'aws-sdk'
require 'base64'
require 'net/http'
require 'net/https'
require 'nokogiri'
require 'uri'

require 'awsudo'

module AWSUDO
  class IdentityProvider
    attr_accessor :idp_login_url, :saml_provider_name, :username, :password

    def self.sts
      return @sts unless @sts.nil?
      @sts = Aws::STS::Client.new(
        credentials: Aws::Credentials.new('a', 'b', 'c'),
        region:      'us-east-1')
    end

    def logger
      AWSUDO.logger
    end

    def logger=(logger)
      AWSUDO.logger = logger
    end

    def initialize(url, name, username, password)
      @idp_login_url = url
      @saml_provider_name = name
      @username = username
      @password = password
      begin
        URI.parse @idp_login_url
      rescue
        raise "`#{@idp_login_url.inspect}' is not a valid IDP login URL"
      end
      if @saml_provider_name.nil? || @saml_provider_name.strip.empty?
        raise "`#{@saml_provider_name.inspect}' is not a valid SAML provider name"
      end
    end

    def saml_request
      raise "should be implemented by subclass"
    end

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
      self.class.sts.assume_role_with_saml(
        role_arn: role_arn,
        principal_arn: principal_arn,
        saml_assertion: saml_assertion).credentials.to_h
    end
  end
end
