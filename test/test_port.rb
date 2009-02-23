require File.join(File.dirname(__FILE__), "test_helper.rb")
require File.join(File.dirname(__FILE__), '..', 'lib','port_upgrade')
require 'shoulda'
include Ports

class TestPort < Test::Unit::TestCase
  context "A Port instance" do
    setup do
      @port = Port.new('wget')
    end

    should "return not nil" do
      assert_not_nil @port
    end

    should "be installed" do
      assert(@port.installed?)
    end
  end

  context "A NoSuchPort instance" do
    setup do
    end

    should "raise NoSuchPort" do
      assert_raise RuntimeError do
        @port = Port.new('NOTwget')
      end
      assert_nil(@port)
    end
  end
  
end
