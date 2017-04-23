#!/usr/bin/env ruby

$testdir = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift File.expand_path(File.join($testdir, "..", "lib"))

require 'awsudo'
require 'test/unit'

class TCAwsudoLogger < Test::Unit::TestCase
  def test_logger
    Logger === AWSUDO.logger
  end
end
