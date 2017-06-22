# Copyright (C) 2015-2017 Electronic Arts Inc.  All rights reserved.

module AWSUDO
  module IdentityProviders
    class Okta < IdentityProvider
      # I'm the abstract class for all authentication factors
      class Factor
        attr_accessor :provider, :vendor_name, :factor_type
        attr_accessor :links, :profile, :state_token
        attr_accessor :logger

        # Initializes the instance with the given parameters.
        def initialize(params)
          @provider = params['provider']
          @vendor_name = params['vendorName']
          @factor_type = params['factorType']
          @links       = params['_links']
          @profile     = params['profile']
          @logger      = AWSUDO.logger
        end

        # It is the subclass responsibility to define this method.
        def verify
          raise "should be implemented by subclass"
        end
      end

      # I'm the namespace for all authentication factor classes
      module Factors
        # Creates an instance of a Factor subclass
        # from the given factor
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

        # I take care of the implementation details for TOTP
        class Totp < Factor
          attr_accessor :credential_id

          # Sets a block to execute for when a prompt is required
          def on_prompt(&block)
            @on_prompt = block
          end

          # Returns the block to execute for when a prompt is required
          def prompt
            @on_prompt
          end

          # Initializes the instance with the given parameters.
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

          # Obtains a session_token after verifying that the user's answer
          # is correct
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
    end
  end
end
