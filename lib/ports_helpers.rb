require 'bz2'
require 'find'
require 'sqlite3'
RECEIPT_PATH = '/opt/local/var/macports/receipts'

class String
  def dot_clean
    return self.gsub(/[ +\/\.-]/,"_")
  end
end

module Ports
  class Utilities
    def self.traverse_receipts(path=nil)
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
        pieces = filename.split("/")
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

    def breadth_first
      
    end
  end
end
