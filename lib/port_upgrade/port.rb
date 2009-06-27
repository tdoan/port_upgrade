require 'port_upgrade/port_upgrade_config'
module Ports
  class Port
    attr_reader :name,:versions,:portfile_path
    @config = PortUpgradeConfig.instance.config
    
    def initialize(portname,receipt_path=nil)
      receipt_path ||= RECEIPT_PATH
      tmpp = File.join(receipt_path,portname)
      @name = portname
      @versions = []
      @portfile_path = nil
      if File.exist?(tmpp) and File.readable?(tmpp)
        @rp = tmpp
        Find.find(@rp) do |d|
          next unless File.directory?(d)
          next if d == @rp
          b = File.basename(d)
          md = /([^+]+)((\+\w+)*)/.match(b)
          @versions << md[1] unless md.nil?
        end
      end

      Dir.entries(get_macports_db_path).each do |d|
        if File.directory?(File.join(get_macports_db_path,d)) && d != '.' && d != '..'
          testpath = File.join(get_macports_db_path,d,@name,'Portfile')
          if File.exist?(testpath)
            @portfile_path = testpath
            break
          end
        end
      end
      raise "NoSuchPort: #{@name}" if @portfile_path.nil?
    end

    def installed?
      @rp.nil? ? false : true
    end

    def receipt_path=(path)
      @rp = path
    end

    def receipt_path
      @rp
    end

    def portfile
      return nil if @portfile_path.nil?
      @portfile ||= Ports::Portfile.new(@portfile_path)
    end

    def name=(n)
      @name = n
    end

    def outdated?
      result = false
      @versions.each do |v|
        if Ports::Utilities.cmp_vers(v,portfile.version) < 0
          result = true
          break
        end
      end
      result
    end

    def get_macports_db_path
      PortUpgradeConfig.instance.get_macports_db_path
    end
    
  end
end
