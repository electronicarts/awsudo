# Copyright (C) 2015-2017 Electronic Arts Inc.  All rights reserved.

require 'awsudo/identity_provider'

module AWSUDO
  module IdentityProviders
    class Okta < IdentityProvider
      class Factor
        attr_accessor :provider, :vendor_name, :factor_type
        attr_accessor :links, :profile, :state_token
        attr_accessor :logger

        def initialize(params)
          @provider = params['provider']
          @vendor_name = params['vendorName']
          @factor_type = params['factorType']
          @links       = params['_links']
          @profile     = params['profile']
          @logger      = AWSUDO.logger
        end

        def verify
          raise "should be implemented by subclass"
        end
      end

      module Factors
        def self.new(factor)
          factor_type = factor['factorType']
          factor_class = FACTORS[factor_type]
          if factor_class.nil?
            raise "factor `#{factor_type}' is not supported"
          end
          factor_class.new(factor)
        end

        class Push < Factor
          def initialize(params)
            super(params)
          end
        end

        class Question < Factor
          attr_accessor :question, :question_text

          def initialize(params)
            super(params)
            @question = params['profile']['question']
            @question_text = params['profile']['questionText']
          end
        end

        class Sms < Factor
          attr_accessor :phone_number

          def initialize(params)
            super(params)
            @phone_number = params['profile']['phoneNumber']
          end
        end

        class Call < Factor
          attr_accessor :phone_number, :phone_extension

          def initialize(params)
            super(params)
            @phone_number = params['profile']['phoneNumber']
            @phone_extension = params['profile']['phoneExtension']
          end
        end

        class Totp < Factor
          attr_accessor :credential_id

          def on_prompt(&block)
            @on_prompt = block
          end

          def prompt
            @on_prompt
          end

          def initialize(params)
            super(params)
            @credential_id = params['profile']['credentialId']
            @on_prompt = lambda do
              fd = IO.sysopen("/dev/tty", "w")
              console = IO.new(fd,"w")
              console.print "Enter passcode: "
              code = STDIN.gets.chomp
              IO.new(fd).close
              code
            end
          end

          def verify
            code = prompt.call
            payload = {'passCode' => code,
                       'stateToken' => state_token
                      }.to_json
            uri = URI.parse(links['verify']['href'])
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
            else
              raise "Error verifying code" # XXX
            end
          end
        end

        FACTORS = {
          'push'                => Push,
          'question'            => Question,
          'sms'                 => Sms,
          'call'                => Call,
          'token:software:totp' => Totp
          # XXX token, web, token:hardware
        }
      end

      attr_accessor :api_endpoint

      def self.new_from_config(config, username, password)
        new(config['IDP_LOGIN_URL'], config['SAML_PROVIDER_NAME'],
            config['API_ENDPOINT'], username, password)
      end

      def on_mfa(&block)
        @on_mfa = block
      end

      def mfa
        @on_mfa
      end

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
