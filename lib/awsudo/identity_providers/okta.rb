# Copyright (C) 2015-2017 Electronic Arts Inc.  All rights reserved.

require 'awsudo/identity_provider'

module AWSUDO
  module IdentityProviders
    class Okta < IdentityProvider
      attr_accessor :api_endpoint

      def initialize(idp_login_url, saml_provider_name, api_endpoint,
                   username, password)
        super(idp_login_url, saml_provider_name, username, password)
        @api_endpoint = api_endpoint
        logger.debug "api_endpoint: <#{@api_endpoint}>"
        begin
          URI.parse(@api_endpoint)
        rescue
          raise "`#{@api_endpoint.inspect}' is not a valid API endpoint"
        end
      end

      def authenticate
        payload = { 
          'username' => username,
          'password' => password,
          'options'  => {
            'multiOptionalFactorEnroll' => false,
          'warnBeforePasswordExpired' => false
          }
        }.to_json
        uri = URI.parse(api_endpoint + '/authn')
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER

        req = Net::HTTP::Post.new(uri.request_uri)
        req.content_type = 'application/json'
        req['Accept'] = 'application/json'
        req.body = payload
        logger.debug {"payload: <#{req.body.inspect}>"}
        res = http.request(req)
        logger.debug {"Headers: <#{res.to_hash.inspect}>"}
        logger.debug {"Body: <#{res.body.inspect}>"}
        result = JSON.parse(res.body)

        case result['status']
        when 'SUCCESS'
          return result['sessionToken']
        when 'MFA_REQUIRED'
          raise 'MFA required'
        else
          raise 'Authentication failed'
        end
      end

      def saml_request
        session_token = authenticate
        uri = URI.parse(idp_login_url)
        req = Net::HTTP::Post.new(uri.request_uri)
        req.set_form_data({'onetimetoken' => session_token})
        req
      end
    end
  end
end
