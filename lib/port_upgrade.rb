#
# ports_helpers.rb: Utility classes for dealing with ports data.
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

$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'yaml'
require 'bz2'
require 'find'
require 'sqlite3'

class String
  def dot_clean
    return self.gsub(/[ +\/\.-]/,"_")
  end
end

module Ports
  VERSION = '0.0.5'
  RECEIPT_PATH = '/opt/local/var/macports/receipts'
  MACPORTS_DB='/opt/local/var/macports/sources/rsync.macports.org/release/ports'
  CONFIG_FILE = 'port_upgrade.conf'
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

  class Utilities

    def breadth_first

    end

    def self.cmp_vers(versa,versb)
      va = Version.new(versa)
      vb = Version.new(versb)
      return va <=> vb
    end
  end

  class Port
  end

  class PortTree
    def initialize(pdb,path=nil)
      @path=path
      @edges_seen = []
      @pdb = pdb
      traverse_receipts
    end

    def size
      s=nil
      @pdb.db.query("select count(*) from ports") do |results|
        s = results.first[0].to_i
      end
      return s
    end

    def receipt_path
      @path || RECEIPT_PATH
    end
    def dump_tree
      ports = nil
      @pdb.db.query("select port,variant from ports order by port") do |results|
        ports = results.to_a
      end
      ports
    end

    def installed
      ports = nil
      @pdb.db.query("select port from ports order by port") do |results|
        ports = results.to_a.flatten
      end
      ports
    end

    def dump_seq(outdated)
      #setup_remports(outdated) unless outdated.nil?
    end

    def setup_remports(outdated)
      begin
        @pdb.db.execute("drop table remports")
      rescue SQLite3::SQLException
      end
      @pdb.db.execute("create table remports(port text, dep text)")
      @pdb.db.execute("create unique index remportsdep on remports(port,dep)")
      outdated.each do |a|
        parents = get_parent_pairs(a)
        begin
          parents.each do |p|
            @pdb.db.execute("insert or ignore into remports values(\"#{p.port}\",\"#{p.dep}\")")
          end
        rescue SQLite3::SQLException => exp
          $stderr.puts "Dup insert into remports:  #{exp}}" if $DEBUG
        end
        @pdb.db.execute("insert or ignore into remports values(\"#{a}\",\"\")")
      end
      @pdb.db.execute('delete from remports where port="gimp-app" and dep="gimp"')
      #File.open("remtree.dot",'w') do |f|
      #  pt = table_to_tree('remports','remports','port','port','dep')
      #  f.write(pt.to_dot)
      #end
    end

    private
    def traverse_receipts
      begin
        @pdb.db.execute("drop table ports")
        @pdb.db.execute("drop table deps")
      rescue SQLite3::SQLException
      end
      @pdb.db.execute("create table ports(port text,version text, variant text)")
      @pdb.db.execute("create table deps(port text, dep text)")
      @pdb.db.execute("create unique index uniqdep on deps(port,dep)")
      receipt_size = receipt_path.split("/").size
      Find.find(receipt_path) do |filename|
        next unless filename =~ /.bz2$/
        next unless File.stat(filename).file?
        pieces = filename.split("/")
        next unless (pieces.size - receipt_size) == 3
        original_portname = pieces[-3]
        md = /([^+]+)((\+\w+)*)/.match(pieces[-2]) #seperate version from variants
        version = md[1]
        variant = md[2]
        portname = filename.split("/")[-3].gsub(/(-|\.|\/)/,'_')  #very unix centric
        @pdb.db.execute("insert into ports values(?,?,?)",original_portname,version,variant)
        #portnames << "#{portname}"
        reader = BZ2::Reader.new(File.open(filename))
        receipt_lines = reader.readlines
        reader.close
        receipt_lines.each do |l|
          if l =~ /depends_lib (\{([^}]*)\}|([^ ]*))/
            deps = $2||$3
            deps.split(" ").each do |d|
              original_depname = d.split(":").last
              depname = d.split(":").last.gsub(/(-|\.|\/)/,'_')
              begin
                @pdb.db.execute("insert into deps values(?,?)",original_portname,original_depname)
              rescue SQLite3::SQLException
              end
            end
          end
          if l =~ /depends_run (\{([^}]*)\}|([^ ]*))/
            deps = $2||$3
            deps.split(" ").each do |d|
              original_depname = d.split(":").last
              depname = d.split(":")[1].gsub(/(-|\.|\/)/,'_')
              begin
                @pdb.db.execute("insert into deps values(?,?)",original_portname,original_depname)
              rescue SQLite3::SQLException
              end
            end
          end
        end
      end
    end
    
    def get_parent_pairs(portname,i=1)
      $stderr.puts "get_parent_pairs: #{portname}, #{i}" if $DEBUG
      rs = @pdb.db.query("select * from deps where dep = ?", portname)
      res = rs.to_a
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
      rs.close
      parents.uniq
    end

  end

  class PortsDB
    def initialize(path=nil,outdated=nil)
      @db = SQLite3::Database.new(':memory:')#('port_tree.db')
      @pt = PortTree.new(self,path)
      @installed = @pt.installed
      @outdated = outdated
      @to_remove = nil
      config_file = locate_config_file
      unless config_file.nil?
        begin
          @config = YAML::load(File.open(config_file))
          @config = {} if @config == false
        rescue Errno::ENOENT
          $stderr.puts("No configuration loaded.")
        end
      else
        $stderr.puts("No configuration loaded.")
      end
    end
    
    def locate_config_file
      to_search = []
      local_dir = File.dirname($0).sub(/bin$/,"")
      local_dir = local_dir == "" ? "." : local_dir
      to_search << File.join(local_dir,"etc",Ports::CONFIG_FILE)
      to_search << File.join(ENV['HOME'],"."+Ports::CONFIG_FILE)
      to_search.each do |path|
        return path if File.readable?(path)
      end
      return nil
    end

    def installed
      @installed
    end

    def db
      @db
    end
    
    def close
      @db.close
    end

    def port_tree
      @pt
    end

    def dump_tree
      @installed.dump_tree
    end

    def to_remove
      return @to_remove unless @to_remove.nil?
      @pt.setup_remports(outdated)
      @db.query("select distinct port from remports order by port") do |rs|
        @to_remove = rs.to_a
      end
    end

    def get_leaves
      $stderr.print "get_leaves " if $DEBUG
      rs = @db.query('select port from remports')
      ports = rs.to_a.flatten.sort.uniq
      rs.close
      $stderr.print "ports: #{ports.size} " if $DEBUG
      rs = @db.query('select dep from remports')
      deps = rs.to_a.flatten.sort.uniq
      rs.close
      $stderr.print "deps: #{deps.size} " if $DEBUG
      diff = (ports - deps).sort
      $stderr.puts "diff: #{diff.size}" if $DEBUG
      diff.each{|p| @db.execute("delete from remports where port = ?",p)}
      diff
    end
    
    def set_outdated(out)
      @outdated = out
    end

    def outdated(reload = false)
      return @outdated unless @outdated.nil? or reload == true
      @outdated = []
      @installed.each do |port|
        d = File.join(@pt.receipt_path,port)
        Dir.entries(d)[2..-1].each do |version|
          d2 = File.join(d,version,'receipt.bz2')
          reader = BZ2::Reader.new(File.new(d2))
          lines = reader.readlines
          cats = []
          lines.collect do |line|
            md = /categories (\{([^}]*)\}|([^ ]*))/.match(line)
            unless md.nil?
              cats << (md[2].nil? ? md[1] : md[2].split.first)
            end
          end
          portfile_path = File.join(MACPORTS_DB,cats.flatten,port,'Portfile')
          unless File.exist?(portfile_path)
            $stderr.puts "Searching for #{port}'s Portfile"
            Dir.entries(MACPORTS_DB).each do |d|
              if File.directory?(File.join(MACPORTS_DB,d)) && d != '.' && d != '..'
                testpath = File.join(MACPORTS_DB,d,port,'Portfile')
                if File.exist?(testpath)
                   portfile_path = testpath
                   break
                 end
              end
            end
          end
          if File.exist?(portfile_path)
            curver = Portfile.new(portfile_path).version
            #puts "%-32s%s < %s" %[port,version.split('+').first,curver] if Ports::Utilities.cmp_vers(version.split('+').first,curver) < 0
            $stderr.puts("#{port}: #{version.split('+').first}, #{curver}") if $DEBUG
            cmp = Ports::Utilities.cmp_vers(version.split('+').first,curver)
            if cmp.nil?
              $stderr.puts "Unable to compare versions: #{[port]}"
            else
               if cmp < 0
                 @outdated << port
               end
             end
          else
            $stderr.puts "Unable to process Portfile (File Not Found) for #{port}"
          end
        end
      end
      @outdated.uniq
    end

    def upgrade(path='port_upgrade.sh')
      final = []
      @pt.setup_remports(outdated) if @to_remove.nil?
      remports = []
      remvariants = Hash.new {|h,k| h[k] = Array.new}
      stmt = @db.prepare("select count(*) from remports")
      dotsh = File.new(path,'w')
      dotsh.chmod(0700)
      $stderr.puts "port_upgrade.sh open for write" if $DEBUG
      dotsh.puts("#!/bin/sh")
      while stmt.execute.to_a.first[0].to_i > 0
          temp = get_leaves
          break if temp.size == 0
          temp.each do |o|
            @db.query("select port,version,variant from ports where port = ?",o) do |rs|
              installed = rs.to_a
              installed.each do |port|
                bu = get_before_uninstall(port[0])
                dotsh.puts(bu) unless bu.nil?
                dotsh.puts("port uninstall #{port[0]} @#{port[1]}#{port[2]} || exit -1")
                au = get_after_uninstall(port[0])
                dotsh.puts(au) unless au.nil?
                remports.push(port[0])
                remvariants[port[0]].push(port[2])
              end
            end
          end
      end
      remports.uniq!
      while remports.size > 0
        port = remports.pop
        if remvariants[port].uniq.size > 1
          $stderr.puts "Found multiple variants for #{port}."
          variantindex = choose_variant(port,remvariants[port])
        else
          variantindex = 0
        end
        bi = get_before_install(port)
        dotsh.puts(bi) unless bi.nil?
        dotsh.puts("port #{get_force(port)} -x install #{port} #{remvariants[port][variantindex]} || exit -1")
        ai = get_after_install(port)
        fi = get_final_install(port)
        final << fi unless fi.nil?
        dotsh.puts(ai) unless ai.nil?
      end
      stmt.close
      final.each{|l| dotsh.puts(l)}
      dotsh.close
      true
    end

    def get_force(portname)
      force = get_port_action(portname,:force_install)
      if force
        return "-f"
      else
        return ""
      end
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

    def get_final_install(portname)
      get_port_action(portname,:final_install)
    end

    private

    def get_port_action(portname,type)
      unless @config.nil?
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

  end

  class Portfile
    def initialize(path)
      @path = path
    end

    def version
      @version ||= find_vers
    end

    private
    def find_vers
      v=nil
      rev=nil
      vars = {}
      portfile = File.new(@path)
      portfile.each do |line|
        case line
        when /^set\s+(\S+)\s+(\S+)/
          vars[$1] = $2
          #$stderr.puts "Var: #{$1}  Val: #{$2}"
        when /^version\s+([^\s]+)/
          v = $1
          while(v =~ /(\$\{([^}]+)\})/) do
            if vars.has_key?($2)
              v[$1] = vars[$2] 
            else
              break
            end
            #$stderr.puts "\n\nREPLACE(#{@path}): #{$1} #{vars[$2]} #{v}\n"
          end
          #break
        when /^revision\s+([^\s]+)/
          rev = $1
          #$stderr.puts "revision found #{rev}"
        when /(\w+\.setup\s+\{[^\}]+\}\s+([^\s]+)|^\w+\.setup\s+[^ ]+ (.*))/
          v = $2 || $3 if v.nil?
          break
        when /(\S+)\s+([^$]+)$/
          vars[$1] = $2.strip
        end
      end
      rev = "0" if rev.nil?
      v = v +"_"+rev
      return v
    end
  end

end
