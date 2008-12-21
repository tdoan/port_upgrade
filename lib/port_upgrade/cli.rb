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
    
    and_process!
  
  class CLI
    def self.execute(stdout, arguments=[])
      pdb = Ports::PortsDB.new(PortUpgrade.flags.receipts)
      pdb.set_outdated(PortUpgrade.flags.outdated.split(" ")) if PortUpgrade.flags.outdated
      $stderr.puts("Outdated: #{pdb.outdated.join(' ')}")
      to_remove = pdb.to_remove
      $stderr.puts "#{to_remove.size} ports to remove: #{to_remove.join(',')}"
      pdb.upgrade(PortUpgrade.flags.output)
      pdb.close
    end
  end
end
