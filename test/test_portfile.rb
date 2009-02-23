require File.join(File.dirname(__FILE__), "test_helper.rb")
require File.join(File.dirname(__FILE__), '..', 'lib','port_upgrade') #,'version')

include Ports

class TestPortfile < Test::Unit::TestCase
  def test_portfile_bad_path
    assert_raise Errno::ENOENT do
      pf = Ports::Portfile.new('/tmp/not_a_path')
    end      
  end
end
