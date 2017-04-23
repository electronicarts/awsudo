# Copyright (C) 2015-2017 Electronic Arts Inc.  All rights reserved.

require 'awsudo/identity_provider'

module AWSUDO
  module IdentityProviders
    class Adfs < IdentityProvider
      def saml_request
        uri = URI.parse(idp_login_url)
        req = Net::HTTP::Post.new(uri.request_uri)
        req.set_form_data({'username' => username, 'password' => password})
        req
      end
    end
  end
end
