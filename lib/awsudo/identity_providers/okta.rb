# Copyright (C) 2015-2017 Electronic Arts Inc.  All rights reserved.

require 'awsudo/identity_provider'
require 'awsudo/identity_providers/okta/factors'

module AWSUDO
  module IdentityProviders
    # I take care of the Okta implementation details
    class Okta < IdentityProvider
      attr_accessor :api_endpoint

      # Creates an instance of the Okta class from the given settings
      def self.new_from_config(config, username, password)
        new(config['IDP_LOGIN_URL'], config['SAML_PROVIDER_NAME'],
            config['API_ENDPOINT'], username, password)
      end

      # Sets a block to execute for when MFA is required
      def on_mfa(&block)
        @on_mfa = block
      end

      # Returns the block to execute for when MFA is required
      def mfa
        @on_mfa
      end

      # Initializes the instance with the given settings.
      def initialize(url, name, endpoint, username, password)
        super(url, name, username, password)
        @api_endpoint = endpoint
        logger.debug { "api_endpoint: <#{@api_endpoint}>" }
        begin
          URI.parse(@api_endpoint)
        rescue
          raise "`#{@api_endpoint.inspect}' is not a valid API endpoint"
        end

        @on_mfa = lambda do |factors|
          return factors.first if factors.size == 1
          while !answer.between(1, factors.size) do
            puts "Select one of the following:\n"
            factors.each_with_index do |factor, index|
              puts "#{index + 1}. #{factor['factor_type']} (#{factor['provider']})"
            end
            answer = STDIN.gets.to_i
            # XXX validate
          end
          factors[answer - 1]
        end
      end

      # Obtains a session_token after the client authenticates successfully
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
          factors = result['_embedded']['factors']
          logger.debug { "factors: #{factors.inspect}" }
          factor = mfa.call(factors)
          logger.debug { "factor: #{factor.inspect}" }
          factor = Factors.new(factor)
          factor.state_token = result['stateToken']
          factor.verify
        else
          raise 'Authentication failed'
        end
      end

      # Builds an HTTP request object for retrieving a SAML assertion.
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
