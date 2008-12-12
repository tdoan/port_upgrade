#!/usr/bin/env ruby
#
# port_upgrade.rb: Main PortUpgrade class and command line interface code.
#
# ====================================================================
# Copyright (c) 2008 Tony Doan <tdoan@tdoan.com>.  All rights reserved.
#
# This software is licensed as described in the file COPYING, which
# you should have received as part of this distribution.  The terms
# are also available at http://github.com/tdoan/port_upgrade/tree/master/COPYING.
# If newer versions of this license are posted there, you may use a
# newer version instead, at your option.
# ====================================================================
#
require "rubygems"
require "sqlite3"
require "yaml"
require File.dirname(__FILE__) + "/lib/ports_helpers.rb"
include Ports

def choose_variant(portname,variants)
  answer=false
  while(!answer)
    $stderr.puts "Please choose from list:"
    variants.each_with_index{|v,i| $stderr.puts "#{i}: #{v=="" ? "(none)" : v}"}
    $stderr.print "> "
    reply = $stdin.gets
    clean = (reply.strip =~ /-?[0-9]+/)
    if (clean == 0)
      answer = true
    else
      $stderr.puts "ERROR, try again."
    end
  end
  return reply.to_i
end

if __FILE__ == $PROGRAM_NAME
  pdb = PortsDB.new
  #puts pdb.outdated
  to_remove = pdb.to_remove
  $stderr.puts "#{to_remove.size} ports to remove: #{to_remove.join(',')}"
  pdb.upgrade
  pdb.close
end
