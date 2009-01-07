#!/usr/bin/env ruby
#
# port_tree.rb: Class (and command line tool) for producing dot language directed graphs of port dependencies.
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
require 'rubygems'
require 'bz2'
require 'find'
require 'erb'
require File.dirname(__FILE__) + "/lib/port_upgrade.rb"
require 'sqlite3'

class PortTree
  
  def initialize(nodes,deps)
    throw "Input data must be an Array of tuples" unless deps.is_a? Array
    @nodes = nodes
    @deps = deps
  end
  
  def to_dot
    template = ERB.new(File.read("port_tree.erb"))
    tree_data = @deps.collect{|o| [o[0].dot_clean,o[1].dot_clean]}.collect{|p| p[1]==""? p[0]:p.join("->")}.sort{|x,y| x <=> y}.join("\n")
    ports = @ports
    deps = @deps.collect{|o| o[1]}.uniq
    leaves = (@nodes - deps).sort
    onodes = (@nodes - leaves).sort
    tree_data += "\n"
    leaves.each{|p| tree_data += "#{p.dot_clean}[label=\"#{p}\" color=green]\n"}
    onodes.each{|p| tree_data += "#{p.dot_clean}[label=\"#{p}\" color=red]\n"}
    template.result(binding)
   end
end

if __FILE__ == $PROGRAM_NAME
  pdb = Ports::PortsDB.new(ARGV[0])
  db = SQLite3::Database.new('port_tree.db')
  deps = nil
  db.query("select port,dep from deps") do |r|
    deps = r.to_a
  end
  ports = nil
  db.query("select distinct port from ports") do |r|
    ports = r.to_a.flatten
  end
  db.close
  pt = PortTree.new(ports,deps)
  puts pt.to_dot
end
