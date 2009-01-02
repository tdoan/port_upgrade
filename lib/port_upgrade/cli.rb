require 'optiflag'

module PortUpgrade extend OptiFlagSet
  
    flag "output" do
      description "Where to output the shell script that performs the upgrade."
    end

    optional_flag "outdated" do
      description "Specify the list of outdated ports to upgrade."
    end

    optional_flag "receipts" do
    end
    
    optional_switch_flag "portoutdated" do
      description "Call \"port outdated\" instead of using internal routine for determining out of date ports. Overides outdated flag."
    end
    
    optional_switch_flag "checkoutdated" do
      description "Compare internal outdated routing with \"port outdated \""
    end
    
    optional_switch_flag "verbose" do
    end

    and_process!
  
  class CLI
    def self.execute(stdout, arguments=[])
      $verbose = true if PortUpgrade.flags.verbose
      if PortUpgrade.flags.portoutdated
        $stderr.print "Running port outdated..."
        outdated = `port outdated`.find_all{|l| (l =~ /(The following|No installed ports are outdated)/).nil? }.collect{|l| l.split[0]}
        $stderr.puts "done"
        if PortUpgrade.flags.checkoutdated
          mypdb = Ports::PortsDB.new(PortUpgrade.flags.receipts)
          myoutdated = mypdb.outdated
          diff = outdated-myoutdated
          if diff.size > 0
            $stderr.puts "Difference with internal: #{(outdated-myoutdated).join(",")}\n\n"
          else
            $stderr.puts "No Difference"
          end
        end
        pdb = Ports::PortsDB.new(PortUpgrade.flags.receipts,outdated)
      else
        pdb = Ports::PortsDB.new(PortUpgrade.flags.receipts)
        pdb.set_outdated(PortUpgrade.flags.outdated.split(" ")) if PortUpgrade.flags.outdated
      end
      $stderr.puts("Outdated(#{pdb.outdated.size}): #{pdb.outdated.join(' ')}")
      to_remove = pdb.to_remove
      $stderr.puts "#{to_remove.size} ports to remove: #{to_remove.join(',')}"
      pdb.upgrade(PortUpgrade.flags.output)
      pdb.close
    end
  end
end
