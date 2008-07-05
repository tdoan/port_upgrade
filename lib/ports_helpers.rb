require 'bz2'
require 'find'
require 'sqlite3'
RECEIPT_PATH = '/opt/local/var/macports/receipts'

# regex to match receipt file filenames and pull out version and variants
#/(\w+(\.\w+)?(\.\d+)?(-\w+)?_\d+)((\+\w+)*)$/

module Ports
  class Utilities
    def self.traverse_receipts(path=nil)
      db = SQLite3::Database.new('port_tree.db')
      begin
        db.execute("drop table ports")
        db.execute("drop table deps")
      rescue SQLite3::SQLException
      end
      db.execute("create table ports(port text)")
      db.execute("create table deps(port text, dep text)")

      #edges = []
      #dep_tree = []
      #@dep_hash = Hash.new{|h,k| h[k] = Array.new}
      #@rev_dep_hash = Hash.new{|h,k| h[k] = Array.new}
      #v_count = Hash.new{|h,k| h[k]=0}
      #portnames=[]

      Find.find(path||RECEIPT_PATH) do |filename|
        next unless filename =~ /.bz2$/
        original_portname = filename.split("/")[-3]  #very unix centric
        portname = filename.split("/")[-3].gsub(/(-|\.|\/)/,'_')  #very unix centric
        db.execute("insert into ports values(\"#{portname}\")")
        #portnames << "#{portname}"
        reader = BZ2::Reader.new(File.open(filename))
        receipt_lines = reader.readlines
        reader.close
        receipt_lines.each do |l|
          if l =~ /depends_lib (\{([^}]*)\}|([^ ]*))/
            deps = $2||$3
            deps.split(" ").each do |d|
              original_depname = d.split(":")[1]
              depname = d.split(":")[1].gsub(/(-|\.|\/)/,'_')
              db.execute("insert into deps values(\"#{original_portname}\",\"#{original_depname}\")")
            end
          end
          if l =~ /depends_run (\{([^}]*)\}|([^ ]*))/
            deps = $2||$3
            deps.split(" ").each do |d|
              original_depname = d.split(":")[1]
              depname = d.split(":")[1].gsub(/(-|\.|\/)/,'_')
              db.execute("insert into deps values(\"#{original_portname}\",\"#{original_depname}\")")
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
