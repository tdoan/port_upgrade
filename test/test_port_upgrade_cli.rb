#require File.join(File.dirname(__FILE__), "test_helper.rb")
require 'test/unit'
require 'port_upgrade/cli'
require 'stringio'
require 'optparse'

class TestPortUpgradeCli < Test::Unit::TestCase
  def setup
    #PortUpgrade::CLI.execute(@stdout_io = StringIO.new, [])
    #@stdout_io.rewind
    #@stdout = @stdout_io.read
  end
  
  def test_not_print_default_output
    #assert_no_match(/To update this executable/, @stdout)
  end
  
  def test_output_flag_requires_argument
    assert_raise OptionParser::MissingArgument do
      PortUpgrade::CLI.execute(stdout_io = StringIO.new, ["-o"])
      stdout_io.rewind
    end
  end
end
