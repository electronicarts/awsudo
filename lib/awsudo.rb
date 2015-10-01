# Copyright (C) 2015 Electronic Arts Inc.  All rights reserved.

require 'aws-sdk'
require 'io/console'
require 'json'
require 'net/http'
require 'net/https'
require 'rexml/document'
require 'socket'
require 'uri'

module AWSUDO
  AWS_ROLES = File.join(ENV['HOME'], '.aws-roles')

  class << self
    attr_reader :idp_login_url, :saml_provider_name
  end

  def self.config(idp_login_url, saml_provider_name)
    @idp_login_url = idp_login_url
    @saml_provider_name = saml_provider_name
  end

  def self.get_federated_credentials
    fd = IO.sysopen("/dev/tty", "w")
    console = IO.new(fd,"w")
    console.print "Login: "
    username = STDIN.gets.chomp
    console.print "Password: "
    password = STDIN.noecho(&:gets).chomp
    console.print "\n"
    [username, password]
  end

  def self.assume_role_using_agent(role)
    socket_name = ENV['AWS_AUTH_SOCK']
    credentials = UNIXSocket.open(socket_name) do |client|
      client.puts role
      response = client.gets
      raise "Connection closed by peer" if response.nil?
      JSON.parse(response.strip)
    end

    raise credentials['error'] if credentials['error']
    credentials
  end

  def self.assume_role_using_password(role)
    username, password = get_federated_credentials
    saml_assertion = get_saml_assertion(username, password)
    role_arn = resolve_role(role)
    assume_role_with_saml(saml_assertion, role_arn).to_h
  end

  def self.assume_role(role)
    assume_role_using_agent(role) rescue assume_role_using_password(role)
  end

  def self.get_saml_assertion(username, password)
    uri = URI.parse(idp_login_url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER

    req = Net::HTTP::Post.new(uri.request_uri)
    req.set_form_data({'username' => username, 'password' => password})
    res = http.request(req)

    raise "Authentication failed" if res['Location'].nil?
    uri = URI.parse(res['Location'])
    req = Net::HTTP::Get.new(uri.request_uri)
    req['Cookie'] = res['Set-Cookie']
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    res = http.request(req)

    doc = REXML::Document.new(res.body)
    REXML::XPath.first(doc, '/html/body/form/input[@name = "SAMLResponse"]/@value').to_s
  end

  def self.assume_role_with_saml(saml_assertion, role_arn)
    principal_arn = "#{role_arn[/^arn:aws:iam::\d+:/]}saml-provider/#{saml_provider_name}"
    sts = Aws::STS::Client.new(credentials: Aws::Credentials.new('a', 'b', 'c'), region: 'us-east-1')
    sts.assume_role_with_saml(
      role_arn: role_arn,
      principal_arn: principal_arn, 
      saml_assertion: saml_assertion).credentials
  end

  def self.resolve_role(role, roles_filename = AWS_ROLES)
    return role if role =~ /^arn:aws:iam::\d+:role\/\S+$/
    raise "`#{role}' is not a valid role" if role =~ /\s/
    line = File.readlines(roles_filename).find {|line| line =~ /^#{role}\s+arn:aws:iam::\d+:role\/\S+\s*$/ }
    raise "`#{role}' is not a valid role" if line.nil?
    role_arn = line.split(/\s+/)[1]
    raise "`#{role}' is not a valid role" if role_arn.nil?
    role_arn
  end
end
