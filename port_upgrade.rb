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
require 'port_tree'
Struct.new('Edge',:port,:dep,:level)
class Struct::Edge
  def <=>(other)
    portdif = self.port <=> other.port
    depdif = self.dep <=> other.dep
    if self.port == other.port and self.dep == other.dep and self.level == other.level
      return 0
    elsif portdif != 0
      return portdif
    elsif depdif != 0
      return depdif
    else
      return self.level <=> other.level
    end
  end
end

class PortUpgrade
  attr_reader :db

  def initialize(args)
    @config = YAML::load(File.open('port_upgrade_conf.yml'))
    @path=args[0]
    @edges_seen = []
    if args.size <= 1
      get_outdated
    else
      @ports = args[1..-1]
    end
    $stderr.puts "Outdated #{@ports.join(',')}"
    #get the sqlite ports table up to date before using it to build remports table
    Ports::Utilities.traverse_receipts(@path)
    #Preserve ports list before messing with it
    File.open("port_tree.out.#{Time.now.strftime("%Y-%m-%d.%H:%M:%S")}","w") do |f|
      Ports::Utilities.dump_tree.sort.each {|entry| f.puts entry.join(" ")}
    end
    @db = SQLite3::Database.new('port_tree.db')
    setup_remports
    true
  end

  def get_outdated
    #get list of outdated ports by shelling out to port outdated and processing what we get back.
    $stderr.print "Running port outdated..."
    @ports = `port outdated`.find_all{|l| (l =~ /(The following|No installed ports are outdated)/).nil? }.collect{|l| l.split[0]}
    $stderr.puts "done"
  end

  def outdated
    @ports
  end

  def setup_remports
    begin
      @db.execute("drop table remports")
    rescue SQLite3::SQLException
    end
    @db.execute("create table remports(port text, dep text)")
    @db.execute("create unique index remportsdep on remports(port,dep)")
    @ports.each do |a|
      parents = get_parent_pairs(a)
      begin
        parents.each do |p|
          @db.execute("insert or ignore into remports values(\"#{p.port}\",\"#{p.dep}\")")
        end
      rescue SQLite3::SQLException => exp
        $stderr.puts "Dup insert into remports:  #{exp}}" if $DEBUG
      end
      @db.execute("insert into remports values(\"#{a}\",\"\")")
    end
    @db.execute('delete from remports where port="gimp-app" and dep="gimp"')
    File.open("remtree.dot",'w') do |f|
      pt = table_to_tree('remports','remports','port','port','dep')
      f.write(pt.to_dot)
    end
  end
  
  def get_parents(portname)
    #$stderr.puts portname
    res = @db.query("select * from ports where dep = ?", portname)
    res.collect{|r| r[0]}.collect{|p| get_parents(p)}.flatten.uniq + [portname]
  end

  def get_parent_pairs(portname,i=1)
    $stderr.puts "get_parent_pairs: #{portname}, #{i}" if $DEBUG
    res = @db.query("select * from deps where dep = ?", portname).to_a
    if res.size == 0
      parents = []
    else
      parents = res.collect{|r| Struct::Edge.new(r[0],portname,i)}
      res.each do |r|
        if (@edges_seen.find{|o| o === [r[0],portname]}).nil?
          @edges_seen << [r[0],portname]
          gp = get_parent_pairs(r[0],i+1)
          parents += gp unless gp.size == 0
        end
      end
    end
    parents.uniq
  end

  def get_all_parents
    @ports.collect{|p| get_parents(p)}.flatten.sort.uniq
  end

  def get_depth(portname,i=0)
    res = @db.query("select * from remports where port =?",portname).to_a
    #$stderr.puts "#{portname} #{res.size}"
    if res.size == 0
      #$stderr.puts "i: #{i}"
      return i
    else
      res.collect{|p| get_depth(p[1],i+1)}.max
    end
  end

  def get_depths

  end
  
  def get_leaves
    $stderr.print "get_leaves " if $DEBUG
    ports = @db.query('select port from remports').to_a.flatten.sort.uniq
    $stderr.print "ports: #{ports.size} " if $DEBUG
    deps = @db.query('select dep from remports').to_a.flatten.sort.uniq
    $stderr.print "deps: #{deps.size} " if $DEBUG
    diff = (ports - deps).sort
    $stderr.puts "diff: #{diff.size}" if $DEBUG
    diff.each{|p| @db.execute("delete from remports where port = ?",p)}
    diff
  end

  def get_before_uninstall(portname)
    get_port_action(portname,:before_uninstall)
  end
  
  def get_after_uninstall(portname)
    get_port_action(portname,:after_uninstall)
  end

  def get_before_install(portname)
    get_port_action(portname,:before_install)
  end

  def get_after_install(portname)
    get_port_action(portname,:after_install)
  end
 
  def get_port_action(portname,type)
    if @config.has_key?(:actions)
      if @config[:actions].has_key?(portname)
        if @config[:actions][portname].has_key?(type)
          @config[:actions][portname][type]
        else
          nil
        end
      end
    end
  end
  
  def table_to_tree(portable,depstable,portcolumn,depcolumna,depcolumnb)
    deps=nil
    db.query("select #{depcolumna},#{depcolumnb} from #{depstable}") do |r|
      deps = r.to_a
    end
    ports = nil
    db.query("select distinct #{portcolumn} from #{portable}") do |r|
      ports = r.to_a.flatten
    end
    PortTree.new(ports,deps)
  end
end

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
  pu = PortUpgrade.new(ARGV)
  $stderr.puts "PortUpgrade.new done" if $DEBUG
  to_remove = pu.db.query("select distinct port from remports").to_a
  $stderr.puts "#{to_remove.size} ports to remove: #{to_remove.collect{|p| p[0]}.join(',')}"
  #parents.collect{|p| [p.port,p.dep]}.sort { |a, b| a[0] <=> b[0] }.each{|o| puts o.join("->")}
  #puts pu.get_depth('wireshark')
  remports = []
  remvariants = Hash.new {|h,k| h[k] = Array.new}
  stmt = pu.db.prepare("select count(*) from remports")
  dotsh = File.new('port_upgrade.sh','w')
  dotsh.chmod(0700)
  $stderr.puts "port_upgrade.sh open for write" if $DEBUG
  dotsh.puts("#!/bin/sh")
  while stmt.execute.to_a.first[0].to_i > 0
    temp = pu.get_leaves
    break if temp.size == 0
    temp.each do |o|
      installed = pu.db.query("select port,version,variant from ports where port = ?",o).to_a
      installed.each do |port|
        bu = pu.get_before_uninstall(port[0])
        dotsh.puts(bu) unless bu.nil?
        dotsh.puts("port uninstall #{port[0]} @#{port[1]}#{port[2]}")
        au = pu.get_after_uninstall(port[0])
        dotsh.puts(au) unless au.nil?
        remports.push(port[0])
        remvariants[port[0]].push(port[2])
      end
    end
  end
  stmt.close
  remports.uniq!
  while remports.size > 0
    port = remports.pop
    if remvariants[port].uniq.size > 1
      $stderr.puts "Found multiple variants for #{port}."
      variantindex = choose_variant(port,remvariants[port])
    else
      variantindex = 0
    end
    bi = pu.get_before_install(port)
    dotsh.puts(bi) unless bi.nil?
    dotsh.puts("port install #{port} #{remvariants[port][variantindex]}")
    ai = pu.get_after_install(port)
    dotsh.puts(ai) unless ai.nil?
  end
end