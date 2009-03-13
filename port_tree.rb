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

class NodeOptions
  def initialize(port,args={})
    case port
    when Ports::Port
      name = port.name
      $stderr.puts "Got a Ports::Port"
    else
      port = Ports::Port.new(port)
      name = port.name
    end
    @options = {}
    @options['label'] = "\"#{name}\""
    @options['color'] = 'red'
    @options = @options.merge(args)
    if port.versions.size > 1
      @options['shape'] = 'record'
      @options['color'] = 'purple'
      @options['label'] = "\"#{name}|{#{port.versions.join("|")}}\""
    end
  end
  
  def []=(key,value)
    @options[key] = value
  end
  
  def to_s
    @options.keys.collect do |key|
      "#{key}=#{@options[key]}"
    end.join(" ")
  end
end

def to_dot(ports,deps)
  template = ERB.new(File.read("port_tree.erb"))
  tree_data = deps.collect{|o| [o[0].dot_clean,o[1].dot_clean]}.collect{|p| p[1]==""? p[0]:p.join("->")}.sort{|x,y| x <=> y}.join("\n")
  #ports = @ports
  deps = deps.collect{|o| o[1]}.uniq
  leaves = (ports - deps).sort
  onodes = (ports - leaves).sort
  tree_data += "\n"
  leaves.each{|p| tree_data += "#{p.dot_clean}[#{NodeOptions.new(@pdb[p],"color"=>"green").to_s}]\n" }# "#{p.dot_clean}[label=\"#{p}\" color=green]\n"}
  onodes.each{|p| tree_data += "#{p.dot_clean}[#{NodeOptions.new(@pdb[p]).to_s}]\n" }
  template.result(binding)
end

if __FILE__ == $PROGRAM_NAME
  @pdb = Ports::PortsDB.new(ARGV[0])
  db = @pdb.db
  deps = nil
  db.query("select port,dep from deps") do |r|
    deps = r.to_a
  end
  ports = nil
  db.query("select distinct port from ports") do |r|
    ports = r.to_a.flatten
  end
  db.close
  puts to_dot(ports,deps)
end
