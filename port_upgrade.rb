#!/usr/bin/env ruby
require "sqlite3"
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

  def initialize(path)
    @edges_seen = []
    get_outdated
    #get the sqlite ports table up to date before using it to build remports table
    Ports::Utilities.traverse_receipts(path)
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
        parents.each{|p| @db.execute("insert into remports values(\"#{p.port}\",\"#{p.dep}\")")}
      rescue SQLite3::SQLException
        $stderr.puts "Dup insert into remports"
      end
      @db.execute("insert into remports values(\"#{a}\",\"\")") if @db.query("select * from remports where port = 'readline'").to_a.size == 0
    end
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

if __FILE__ == $PROGRAM_NAME
  pu = PortUpgrade.new(ARGV[0])
  $stderr.puts "#{pu.db.query("select count(distinct port) from remports").to_a.first[0].to_i} ports to remove"
  #parents.collect{|p| [p.port,p.dep]}.sort { |a, b| a[0] <=> b[0] }.each{|o| puts o.join("->")}
  #puts pu.get_depth('wireshark')
  remports = []
  stmt = pu.db.prepare("select count(*) from remports")
  dotsh = File.new('port_upgrade.sh','w')
  while stmt.execute.to_a.first[0].to_i > 0
    temp = pu.get_leaves
    temp.each do |o|
      installed = pu.db.query("select port,version,variant from ports where port = ?",o).to_a
      installed.each do |port|
        dotsh.puts("port uninstall #{port[0]} @#{port[1]}#{port[2]}")
        remports.push "#{port[0]} #{port[2]}"
      end
    end
  end
  stmt.close
  while remports.size > 0
    dotsh.puts("port install #{remports.pop}")
  end
end