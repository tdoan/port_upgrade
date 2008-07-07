#!/usr/bin/env ruby
require 'bz2'
require 'find'
require 'erb'
require 'sqlite3'
db = SQLite3::Database.new('port_tree.db')
begin
  db.execute("drop table ports")
rescue SQLite3::SQLException
end
db.execute("create table ports(port text, dep text)")
edges = []
dep_tree = []
@dep_hash = Hash.new{|h,k| h[k] = Array.new}
@rev_dep_hash = Hash.new{|h,k| h[k] = Array.new}
v_count = Hash.new{|h,k| h[k]=0}
portnames=[]
Find.find(ARGV[0]||'/opt/local/var/macports/receipts/') do |filename|
  next unless filename =~ /.bz2$/
  original_portname = filename.split("/")[-3]  #very unix centric
  portname = filename.split("/")[-3].gsub(/(-|\.|\/)/,'_')  #very unix centric
  portnames << "#{portname}"
  reader = BZ2::Reader.new(File.open(filename))
  receipt_lines = reader.readlines
  reader.close
  receipt_lines.each do |l|
    if l =~ /depends_lib (\{([^}]*)\}|([^ ]*))/
      deps = $2||$3
      deps.split(" ").each do |d|
        original_depname = d.split(":")[1]
        depname = d.split(":")[1].gsub(/(-|\.|\/)/,'_')
        dep_tree << "#{portname}->#{depname}"
        @dep_hash[portname] << depname
        @rev_dep_hash[depname] << portname
        db.execute("insert into ports values(\"#{original_portname}\",\"#{original_depname}\")")
        v_count[depname]+=1
      end
    end
  end
end

tree_data = dep_tree.uniq.sort.join("\n")
tree_data += "\n"
portnames.each {|name| v_count[name]=0 unless v_count.has_key?(name)}
v_count.each_pair do |port,count|
  tree_data += "#{port}"
  case count
    when 0
      tree_data += "[color=green]\n"
      edges << port
    else
      tree_data += "[color=red]\n"
    end
end
#$stderr.puts v_count.sort{|x,y| x[1]<=>y[1]}.inspect
template = ERB.new(File.read("port_tree.erb"))
puts template.result(binding)

def bf_search(hash,name,list=[])
  return [] unless hash[name].size > 0
  #$stderr.puts "#{name}: #{hash[name].inspect}"
  list += hash[name].collect{|n| bf_search(hash,n,list)}
  return list
end

#puts bf_search(@dep_hash,'wireshark').inspect
#$stderr.puts @rev_dep_hash['gtk2']
$stderr.puts edges.size
$stderr.puts edges.sort.join(",")