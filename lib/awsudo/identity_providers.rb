# Copyright (C) 2015-2017 Electronic Arts Inc.  All rights reserved.

module AWSUDO
  module IdentityProviders
    def self.new(idpname, config, username, password)
      case idpname
        when :Adfs
          idp = AWSUDO::IdentityProviders::Adfs.
                  new(config['IDP_LOGIN_URL'], config['SAML_PROVIDER_NAME'],
                    username, password)
        when :Okta
          idp = AWSUDO::IdentityProviders::Okta.
                  new(config['IDP_LOGIN_URL'], config['SAML_PROVIDER_NAME'],
                      config['API_ENDPOINT'], username, password)
        else
          raise "#{idpname.to_s} is not a supported identity provider"
      end
    end
  end
end

require 'awsudo/identity_providers/adfs.rb'
require 'awsudo/identity_providers/okta.rb'
