require File.join(File.dirname(__FILE__), "test_helper.rb")
require File.join(File.dirname(__FILE__), '..', 'lib','port_upgrade','version')
require 'test/unit'
include Ports

class TestVersion < Test::Unit::TestCase
  def setup
    raw_tests = %q{ImageMagick                    6.4.6-7_0 < 6.4.8-1_0     
    binutils                       2.17_0 < 2.19_0           
    bison                          2.4_1 < 2.4.1_0
    boost                          1.35.0_2 < 1.37.0_0       
    cairo                          1.8.4_0 < 1.8.6_1         
    dbus                           1.2.4_2 < 1.2.10_0        
    dbus-glib                      0.76_1 < 0.78_0           
    fftw-3                         3.2_0 < 3.2_1             
    fontconfig                     2.6.0_0 < 2.6.0_1         
    git-core                       1.6.0.4_0 < 1.6.1_0       
    gtk2                           2.14.4_1 < 2.14.5_0       
    iso-codes                      3.2_0 < 3.5_0             
    libgpg-error                   1.6_0 < 1.7_0             
    libidl                         0.8.11_0 < 0.8.12_0       
    libpng                         1.2.33_0 < 1.2.34_0       
    libtool                        1.5.26_0 < 2.2.6a_0       
    mhash                          0.9.9_0 < 0.9.9.9_0       
    pango                          1.22.3_0 < 1.22.4_0       
    proj                           4.6.0_0 < 4.6.1_0         
    py25-hashlib                   2.5.2_0 < 2.5.4_0         
    py25-sqlite3                   2.5.2_0 < 2.5.4_0         
    py25-zlib                      2.5.2_0 < 2.5.4_0         
    python25                       2.5.2_7 < 2.5.4_0         
    subversion                     1.5.4_0 < 1.5.5_0         
    subversion-perlbindings        1.5.4_0 < 1.5.5_0         
    wireshark                      1.0.4_0 < 1.0.5_0         
    xorg-util-macros               1.2.0_0 < 1.2.1_0         
    xrender                        0.9.4_1 < 0.9.4_4
}
  @tests = raw_tests.collect{|l| parts = l.split(" "); [parts[1],parts[3]] }
  end

  def test_1
    v1 = Version.new("1.2.6_0")
    v2 = Version.new("1.2.10_0")
    assert_equal(v1 <=> v2, -1)
  end

  def test_2
    v1 = Version.new("1.5.26_0")
    v2 = Version.new("2.2.6a_0")
    assert_equal(v1 <=> v2, -1)
  end

  def test_3
    v1 = Version.new("2.2.6b_0")
    v2 = Version.new("2.2.6a_0")
    assert_equal(v1 <=> v2, 1)
  end
  
  def test_4
    v1 = Version.new("2.24a.1")
    v2 = Version.new("2.24b.1")
    assert_equal(v1 <=> v2, -1)
  end
  
  def test_5
    v1 = Version.new("5.820_0")
    v2 = Version.new("5.820 LWP_0")
    assert_equal(v1 <=> v2, 0)
  end
  
  def test_current
    @tests.each do |test|
      v1 = Version.new(test[0])
      v2 = Version.new(test[1])
      assert_equal(v1 <=> v2, -1)
    end
  end
  
  def test_other_class
    assert_raise RuntimeError do
      v = Version.new(["2"])
    end
  end
end