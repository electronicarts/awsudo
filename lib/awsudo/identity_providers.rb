# Copyright (C) 2015-2017 Electronic Arts Inc.  All rights reserved.

module AWSUDO
  # I'm the namespace for all identity provider classes
  module IdentityProviders
    # Creates an instance of an IdentityProvider subclass
    # from the given settings
    def self.new(idpname, config, username, password)
      self.const_get(idpname).new_from_config(config, username, password)
    end
  end
end

require 'awsudo/identity_providers/adfs.rb'
require 'awsudo/identity_providers/okta.rb'
