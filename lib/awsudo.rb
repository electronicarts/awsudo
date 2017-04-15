# Copyright (C) 2015 Electronic Arts Inc.  All rights reserved.

require 'aws-sdk'
require 'io/console'
require 'json'
require 'logger'
require 'net/http'
require 'net/https'
require 'rexml/document'
require 'socket'
require 'uri'

module AWSUDO
  def self.logger
    return @logger unless @logger.nil?
    @logger = Logger.new(STDERR)
    @logger.level = Logger::WARN
    @logger
  end

  def self.logger=(logger)
    @logger = logger
  end

  class << self
    attr_accessor :idp_login_url, :saml_provider_name
  end

  def self.ask_for_credentials
    fd = IO.sysopen("/dev/tty", "w")
    console = IO.new(fd,"w")
    console.print "Login: "
    username = STDIN.gets.chomp
    console.print "Password: "
    password = STDIN.noecho(&:gets).chomp
    console.print "\n"
    [username, password]
  end

  def self.get_saml_assertion(username, password)
    uri = URI.parse(idp_login_url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER

    req = Net::HTTP::Post.new(uri.request_uri)
    req.set_form_data({'username' => username, 'password' => password})
    res = http.request(req)

    logger.debug "Location: <#{res['Location']}>"
    raise "Authentication failed" if res['Location'].nil?
    uri = URI.parse(res['Location'])
    req = Net::HTTP::Get.new(uri.request_uri)
    req['Cookie'] = res['Set-Cookie']
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    res = http.request(req)

    doc = REXML::Document.new(res.body)
    REXML::XPath.first(doc,
      '/html/body/form/input[@name = "SAMLResponse"]/@value').to_s
  end

  def self.assume_role_with_saml(role_arn, saml_assertion)
    principal_arn = "#{role_arn[/^arn:aws:iam::\d+:/]}saml-provider/#{saml_provider_name}"
    logger.debug "principal_arn: <#{principal_arn}>"
    sts = Aws::STS::Client.new(
      credentials: Aws::Credentials.new('a', 'b', 'c'),
      region: 'us-east-1')
    sts.assume_role_with_saml(
      role_arn: role_arn,
      principal_arn: principal_arn,
      saml_assertion: saml_assertion).credentials
  end

  def self.assume_role_with_password(role_arn, username, password)
    logger.debug "role_arn: <#{role_arn}>"
    saml_assertion = get_saml_assertion(username, password)
    logger.debug "saml_assertion: #{saml_assertion.inspect}"
    assume_role_with_saml(role_arn, saml_assertion).to_h
  end

  def self.assume_role_with_agent(role_arn, socket_name)
    logger.debug "role_arn: <#{role_arn}>"
    logger.debug "socket_name: <#{socket_name}>"
    credentials = UNIXSocket.open(socket_name) do |client|
      client.puts role_arn
      response = client.gets
      raise "Connection closed by peer" if response.nil?
      JSON.parse(response.strip)
    end

    raise credentials['error'] if credentials['error']
    credentials
  end
end
