require 'singleton'
require 'yaml'

module Ports
  CONFIG_FILE = 'port_upgrade.conf'
  class PortUpgradeConfig
    include Singleton
    @@config=nil
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
    
    def get_macports_db_path
      unless config.nil?
        if config.has_key?(:macports_db_path)
          config[:macports_db_path]
        else
          MACPORTS_DB
        end
      end
    end
    
    def config
      return @@config unless @@config.nil?

      config_file = locate_config_file
      unless config_file.nil?
        begin
          @@config = YAML::load(File.open(config_file))
          @@config = {} if @@config == false
          return @@config
        rescue Errno::ENOENT
          throw "No configuration loaded."
        rescue ArgumentError
          throw "Badly formed config file."
        end
      else
        #throw "No configuration loaded."
        return nil
      end
    end
  end
end
