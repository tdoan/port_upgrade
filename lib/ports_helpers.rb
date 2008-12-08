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

require 'bz2'
require 'find'
require 'sqlite3'

class String
  def dot_clean
    return self.gsub(/[ +\/\.-]/,"_")
  end
end

module Ports
  RECEIPT_PATH = '/opt/local/var/macports/receipts'
  MACPORTS_DB='/opt/local/var/macports/sources/rsync.macports.org/release/ports'
  
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
      sa = versa.tr("._-","")
      sb = versb.tr("._-","")
      a=sa.to_i
      b=sb.to_i
      #a==0 ? asize=0 : asize = Math.log10(a).to_i
      asize=sa.length
      #b==0 ? bsize=0 : bsize = Math.log10(b).to_i
      bsize=sb.length
      diff = asize-bsize
      if diff < 0
        a = a * (10 ** diff.abs)
      elsif diff > 0
        b = b * (10 ** diff.abs)
      end
      a <=> b
    end
  end
  
  class Port
  end
  
  class PortTree
    def initialize(path=nil)
      traverse_receipts(path)
    end

    def size
      s=nil
      get_db do |db|
        db.query("select count(*) from ports") do |results|
          s = results.first[0].to_i
        end
      end
      return s
    end

    def dump_tree
      ports = nil
      get_db do |db|
        db.query("select port,variant from ports order by port") do |results|
          ports = results.to_a
        end
      end
      ports
    end

    def installed
      ports = nil
      get_db do |db|
        db.query("select port from ports order by port") do |results|
          ports = results.to_a.flatten
        end
      end
      ports
    end

    def dump_seq(outdated)
      setup_remports(outdated) unless outdated.nil?
    end

private
    def traverse_receipts(path=nil)
      db = SQLite3::Database.new('port_tree.db')
      begin
        db.execute("drop table ports")
        db.execute("drop table deps")
      rescue SQLite3::SQLException
      end
      db.execute("create table ports(port text,version text, variant text)")
      db.execute("create table deps(port text, dep text)")
      db.execute("create unique index uniqdep on deps(port,dep)")

      #edges = []
      #dep_tree = []
      #@dep_hash = Hash.new{|h,k| h[k] = Array.new}
      #@rev_dep_hash = Hash.new{|h,k| h[k] = Array.new}
      #v_count = Hash.new{|h,k| h[k]=0}
      #portnames=[]

      Find.find(path||RECEIPT_PATH) do |filename|
        next unless filename =~ /.bz2$/
        next unless File.stat(filename).file?
        pieces = filename.split("/")
        next unless pieces.size == 9
        original_portname = pieces[-3]
        md = /([^+]+)((\+\w+)*)/.match(pieces[-2]) #seperate version from variants
        version = md[1]
        variant = md[2]
        portname = filename.split("/")[-3].gsub(/(-|\.|\/)/,'_')  #very unix centric
        db.execute("insert into ports values(?,?,?)",original_portname,version,variant)
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
                db.execute("insert into deps values(?,?)",original_portname,original_depname)
              rescue SQLite3::SQLException
              end
            end
          end
          if l =~ /depends_run (\{([^}]*)\}|([^ ]*))/
            deps = $2||$3
            deps.split(" ").each do |d|
              original_depname = d.split(":")[1]
              depname = d.split(":")[1].gsub(/(-|\.|\/)/,'_')
              begin
                db.execute("insert into deps values(?,?)",original_portname,original_depname)
              rescue SQLite3::SQLException
              end
            end
          end
        end
      end
    db.close
    end

    def get_parent_pairs(db,portname,i=1)
      $stderr.puts "get_parent_pairs: #{portname}, #{i}" if $DEBUG
      res = db.query("select * from deps where dep = ?", portname).to_a
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

    def setup_remports(outdated)
      get_db do |db|
        begin
          db.execute("drop table remports")
        rescue SQLite3::SQLException
        end
        db.execute("create table remports(port text, dep text)")
        db.execute("create unique index remportsdep on remports(port,dep)")
        outdated.each do |a|
          parents = get_parent_pairs(db,a)
          begin
            parents.each do |p|
              db.execute("insert or ignore into remports values(\"#{p.port}\",\"#{p.dep}\")")
            end
          rescue SQLite3::SQLException => exp
            $stderr.puts "Dup insert into remports:  #{exp}}" if $DEBUG
          end
          db.execute("insert into remports values(\"#{a}\",\"\")")
        end
        db.execute('delete from remports where port="gimp-app" and dep="gimp"')
        File.open("remtree.dot",'w') do |f|
          pt = table_to_tree('remports','remports','port','port','dep')
          f.write(pt.to_dot)
        end
      end
    end

    def get_db
      db = SQLite3::Database.new('port_tree.db')
      yield db
      db.close
    end
  end
  
  class PortDB
    def initialize(outdated=nil)
      @pt = PortTree.new
      @installed = @pt.installed
      @outdated = outdated
    end

    def installed
      @installed
    end
    
    def port_tree
      @pt
    end

    def dump_tree
      @installed.dump_tree
    end

    def outdated(reload = true)
      return @outdated unless @outdated.nil? or reload == true
      @outdated = []
      @installed.each do |port|
        d = File.join(Ports::RECEIPT_PATH,port)
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
          e = File.exist?(portfile_path)
          curver = Portfile.new(portfile_path).version
          #puts "%-32s%s < %s" %[port,version.split('+').first,curver] if Ports::Utilities.cmp_vers(version.split('+').first,curver) < 0
          @outdated << port if Ports::Utilities.cmp_vers(version.split('+').first,curver) < 0
        end
      end
      @outdated
    end

    def upgrade
      
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
        when /\w+\.setup\s+(\S+)? ([\S]+)/
          v = $2 if v.nil?
          break
        when /(\S+)\s+([^$]+)$/
          vars[$1] = $2
        end
      end
      rev = "0" if rev.nil?
      v = v +"_"+rev
      return v
    end
  end

end
