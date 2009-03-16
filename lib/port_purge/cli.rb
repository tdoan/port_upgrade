require 'optparse'
require 'ostruct'
require 'yaml'

module PortPurge
  class CLI
    DOTFILEPATH = File.join(ENV['HOME'],".port_upgrade_ports")
    def self.execute(stdout, arguments=[])
      options = OpenStruct.new
      options.filter = nil
      opts = OptionParser.new do |opts|
        opts.banner = "Usage: port_purge [-f filter]"
        opts.on("-f", "--filter FILTER","FILTER ports to purge") do |filter|
          options.filter  = filter
        end
      end      
      opts.parse!
      
      @to_remove = []
      @keep = []
      begin
        @keep = YAML::load(File.read(DOTFILEPATH)) if File.readable?(DOTFILEPATH)
      rescue ArgumentError
        $stderr.puts("Badly formed .port_upgrade_ports file. Skipping.")
      end
      @pdb = Ports::PortsDB.new
      ports = @pdb.db.query('select port from ports').collect{|p| p[0]}
      deps = @pdb.db.query('select dep from deps').collect{|p| p[0]}
      $stderr.puts "Leaves:"
      diff = (ports-deps).sort
      $stderr.puts "Applying filter /#{options.filter}/" unless options.filter.nil?
      diff.each do |leaf|
        next if @keep.include? leaf
        unless options.filter.nil?
          next unless Regexp.compile(options.filter).match(leaf)
        end
        
        $stderr.print leaf
        $stderr.print "   Remove? (Y/N/S/Q)"
        reply = $stdin.gets
        case reply.strip
        when /^(yes|y)$/i
          @to_remove << leaf
        when /^(quit|q)$/i
          exit -1
        when /^(skip|s)$/i
          break
          $stderr.puts
        else
          @keep << leaf
        end
      end
      File.open(DOTFILEPATH,'w') do |f|
        f.write(@keep.to_yaml)
      end
      exit 0 unless @to_remove.size > 0
      $stderr.print "Really remove #{@to_remove.join(" ")} ? (type yes) "
      reply = $stdin.gets
      if reply =~ /^yes$/i
        @to_remove.each do |leaf|
          s = "port uninstall #{leaf}"
          $stderr.puts s
          system(s)
        end
      else
        $stderr.puts "Exiting"
        exit -1
      end
    end
  end
end