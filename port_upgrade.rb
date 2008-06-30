#!/usr/bin/env ruby
require "sqlite3"
require File.dirname(__FILE__) + "/lib/ports_helpers.rb"

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
    @db = SQLite3::Database.new('port_tree.db')
    begin
      @db.execute("drop table remports")
    rescue SQLite3::SQLException
    end
    @db.execute("create table remports(port text, dep text)")

    @ports = args.collect{|a| a}
    @edges_seen = []
    true
  end

  def get_parents(portname)
    #$stderr.puts portname
    res = @db.query("select * from ports where dep = ?", portname)
    res.collect{|r| r[0]}.collect{|p| get_parents(p)}.flatten.uniq + [portname]
  end

  def get_parent_pairs(portname,i=1)
    #$stderr.puts portname
    res = @db.query("select * from deps where dep = ?", portname).to_a
    if res.size == 0
      parents = []
    else
      parents = res.collect{|r| Struct::Edge.new(r[0],portname,i)}
      res.each do |r|
        if (@edges_seen.find{|o| o === [r[0],i+1]}).nil?
          @edges_seen << [r[0],i+i]
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
    ports = @db.query('select port from remports').to_a.flatten.sort.uniq
    deps = @db.query('select dep from remports').to_a.flatten.sort.uniq
    diff = (ports - deps).sort
    diff.each{|p| @db.execute("delete from remports where port = ?",p)}
    diff
  end

end

if __FILE__ == $PROGRAM_NAME
  dotsh = File.new('port_upgrade.sh','w')
  #get the sqlite ports table up to date before using it to build remports table
  Ports::Utilities.traverse_receipts
  #get list of outdated ports by shelling out to port outdated and processing what we get back.
  $stderr.print "Running port outdated..."
  outdated = `port outdated`.find_all{|l| (l =~ /(The following|No installed ports are outdated)/).nil? }.collect{|l| l.split[0]}
  $stderr.puts "done"
  pu = PortUpgrade.new(outdated)
  outdated.each do |a|
    parents = pu.get_parent_pairs(a)
    parents.each{|p| pu.db.execute("insert into remports values(\"#{p.port}\",\"#{p.dep}\")")}
    pu.db.execute("insert into remports values(\"#{a}\",\"\")") if pu.db.query("select * from remports where port = 'readline'").to_a.size == 0
    #puts "#{a}: #{parents.size}"
  end
  $stderr.puts "#{pu.db.query("select count(distinct port) from remports").to_a.first[0].to_i} ports to remove"
  #parents.collect{|p| [p.port,p.dep]}.sort { |a, b| a[0] <=> b[0] }.each{|o| puts o.join("->")}
  #puts pu.get_depth('wireshark')
  remports = []
  while pu.db.query("select count(*) from remports").to_a.first[0].to_i > 0
    temp = pu.get_leaves
    temp.each do |o|
      installed = `port installed #{o}`.find_all{|l| (l =~ /The following/).nil? }.collect{|p| p.gsub(/ \(active\)/,"").strip}
      `port installed #{o}`.find_all{|l| (l =~ /The following/).nil? }.collect{|p| p.gsub(/ \(active\)/,"").strip}.each do |q|
        dotsh.puts("port uninstall #{q}")
      end
      remports.push installed.collect{|o| o.gsub(/ @[^+]*/," ")}.last
    end
    #puts temp.join(",")
  end

  while remports.size > 0
    dotsh.puts("port install #{remports.pop}")
  end
end