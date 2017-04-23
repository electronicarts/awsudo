$testdir = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift File.expand_path($testdir)

require 'test/unit'
require 'tc_logger'
require 'tc_identity_providers'
require 'tc_adfs'
require 'tc_okta'
