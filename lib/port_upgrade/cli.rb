require 'optparse'
require 'ostruct'

module PortUpgrade
  
  class CLI
    def self.execute(stdout, arguments=[])
      options = OpenStruct.new
      options.output = nil
      options.receipts = nil
      options.outdated = nil
      options.portoutdated = false
      options.checkoutdated = false
      options.verbose = false
      
      opts = OptionParser.new do |opts|
        opts.banner = "Usage: port_upgrade.rb -oFILENAME [options]"
        opts.on("-o", "--output FILE","FILE to output shell commands") do |output|
          options.output  = output
        end
        opts.on("--receipts PATH","PATH to receipts files") do |receipts|
          options.receipts  = receipts
        end
        opts.on("--outdated OUTDATED","Space seperated list of ports to mark as outdated") do |outdated|
          options.outdated  = outdated.split(" ")
        end
        opts.on("--portoutdated",'Use `port outdated`(slow) instead of internal version checking routine(fast)') do |po|
          options.portoutdated = po
          $stderr.puts "PORTOUTDATED: #{po}"
        end
        opts.on("--checkoutdated",'Check `port outdated` against internal routine for inconsistencies') do |co|
          options.checkoutdated = co
          $stderr.puts "CHECKOUTDATED: #{co}"
        end
        opts.on("-p",'Add pid to the end of the outputfile') do 
          options.pid = "." + Process.pid.to_s
        end
        opts.on_tail("-V", "--version","Show version") do
          $stderr.puts "port_upgrade #{Ports::VERSION}"
          exit
        end
        opts.on_tail("-h", "--help", "Show this message") do
          puts opts
          exit
        end
        opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
          $stderr.puts "VERBOSE: #{v}"
          $stderr.puts Ports::PortUpgradeConfig.instance.get_macports_db_path
          options.verbose = v
        end
      end
      opts.parse!(arguments)
      if !options.output
        puts opts
        exit 1
      end
      $verbose = true if options.verbose
      options.output += options.pid if options.pid
      if options.portoutdated
        $stderr.print "Running port outdated..."
        outdated = `port outdated`.find_all{|l| (l =~ /(The following|No installed ports are outdated)/).nil? }.collect{|l| l.split[0]}
        $stderr.puts "done"
        if options.checkoutdated
          mypdb = Ports::PortsDB.new(options.receipts)
          myoutdated = mypdb.outdated
          diff = outdated-myoutdated
          if diff.size > 0
            $stderr.puts "Difference with internal: #{(outdated-myoutdated).join(",")}\n\n"
          else
            $stderr.puts "No Difference"
          end
        end
        pdb = Ports::PortsDB.new(options.receipts,outdated)
      else
        pdb = Ports::PortsDB.new(options.receipts)
        pdb.set_outdated(options.outdated) if options.outdated
      end
      $stderr.puts("Outdated(#{pdb.outdated.size}):")
      $stderr.puts "#{pdb.outdated.uniq.collect {|portname| p=pdb[portname] ;"#{portname}(#{p.versions.join(", ")}) < #{p.portfile.version}"}.join("\n")}"
      to_remove = pdb.to_remove
      $stderr.puts "#{to_remove.size} ports to remove: #{to_remove.join(',')}"
      pdb.upgrade(options.output)
      pdb.close
    end
  end
end
