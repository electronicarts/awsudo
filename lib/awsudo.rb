# Copyright (C) 2015-2017 Electronic Arts Inc.  All rights reserved.

require 'io/console'
require 'json'
require 'logger'
require 'socket'
require 'uri'

# I'm the namespace for the awsudo library.
module AWSUDO
  @logger = Logger.new(STDERR)
  @logger.level = Logger::WARN

  class << self
    attr_accessor :logger
  end

  # Asks the aws-agent through socket_name to assume role_arn.
  # It expects a JSON response with either an error message or
  # AWS temporary keys.
  def self.assume_role_with_agent(role_arn, socket_name)
    logger.debug {"role_arn: <#{role_arn}>"}
    logger.debug {"socket_name: <#{socket_name}>"}
    keys = UNIXSocket.open(socket_name) do |client|
      client.puts role_arn
      response = client.gets
      logger.debug {"response: <#{response}>"}
      raise "Connection closed by peer" if response.nil?
      JSON.parse(response.strip)
    end

    raise keys['error'] unless keys['error'].nil?
    keys
  end

  # Asks the user interactively for username and password
  def self.ask_for_credentials
    fd = IO.sysopen("/dev/tty", "w")
    console = IO.new(fd,"w")
    console.print "Login: "
    username = STDIN.gets.chomp
    console.print "Password: "
    password = STDIN.noecho(&:gets).chomp
    console.print "\n"
    IO.new(fd).close
    [username, password]
  end

  # Retrieves awsudo's settings from filename
  def self.load_config(filename)
    config = Hash[*File.read(filename).scan(/^\s*(\w+)\s*=\s*(.*)\s*$/).flatten]
    logger.debug { "config: <#{config.inspect}>" }
    config
  end
end

require 'awsudo/identity_providers'
