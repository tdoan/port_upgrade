#!/usr/bin/env ruby
require 'bz2'
require 'find'
require 'erb'
require File.dirname(__FILE__) + "/lib/ports_helpers.rb"
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
  Ports::Utilities.traverse_receipts(ARGV[0])
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