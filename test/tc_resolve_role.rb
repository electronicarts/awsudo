#!/usr/bin/env ruby

$testdir = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift File.expand_path(File.join($testdir, "..", "lib"))

require 'awsudo'
require 'test/unit'

class TCAwsudoResolveRole < Test::Unit::TestCase
  def setup
    @roles_filename = File.join($testdir, 'fixtures', 'aws-roles')
  end

  def test_resolve_role
    assert_equal AWSUDO.resolve_role("role-alias-1", @roles_filename), "arn:aws:iam:1234567890:role/role1"
    assert_equal AWSUDO.resolve_role("arn:aws:iam:1234567890:role/role2", @roles_filename), "arn:aws:iam:1234567890:role/role2"
    assert_raise(RuntimeError) { AWSUDO.resolve_role("role-non-existent", @roles_filename) }
    assert_raise(RuntimeError) { AWSUDO.resolve_role("role-alias-3-empty", @roles_filename) }
    assert_raise(RuntimeError) { AWSUDO.resolve_role("role-alias-4-trailing-spaces", @roles_filename) }
  end
end
