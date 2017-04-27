# Copyright (C) 2015-2017 Electronic Arts Inc.  All rights reserved.

require 'io/console'
require 'json'
require 'logger'
require 'socket'
require 'uri'

module AWSUDO
  @logger = Logger.new(STDERR)
  @logger.level = Logger::WARN

  class << self
    attr_accessor :logger
  end

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

  def self.load_config(filename)
    config = Hash[*File.read(filename).scan(/^\s*(\w+)\s*=\s*(.*)\s*$/).flatten]
    logger.debug { "config: <#{config.inspect}>" }
    config
  end
end

require 'awsudo/identity_providers'
