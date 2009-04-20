module Ports
  class Version
    include Comparable
    attr_reader :parts,:portrev
    def initialize(s)
      @parts,@portrev = breakup_version(s)
    end

    def <=>(other)
      return 0 if @parts.nil? or other.parts.nil?
      $stderr.puts("self: #{@parts.inspect}") if $DEBUG
      $stderr.puts("other: #{other.parts.inspect}") if $DEBUG
      cmp = 0
      numparts = @parts.size>other.parts.size ? @parts.size : other.parts.size
      0.upto(numparts-1) do |i|
        p = i>=@parts.size ? "-1" : @parts[i]
        q = i>=other.parts.size ? "-1" : other.parts[i]
        #numsubparts = p.size>q.size ? p.size : q.size
        a = p =~ /^-?[0-9]+$/ ? p.to_i : p
        b = q =~ /^-?[0-9]+$/ ? q.to_i : q
        $stderr.puts "#{a.inspect} <=> #{b.inspect}" #if $DEBUG
        if a.instance_of?(b.class)
          cmp = a <=> b
        else
          $stderr.puts "Can't compare different classes #{a.class.to_s} <=> #{b.class.to_s}" if $DEBUG
          cmp = 0
        end
        return cmp if cmp != 0
      end
      cmp = @portrev <=> other.portrev
      cmp
    end

    private
    def breakup_version(v)
      return nil if v.nil?
      raise "Bad input to version; not String" unless v.is_a?(String)
      if v =~ /\[[^\]]+\]/
        $stderr.puts "code version: #{v}"
        result = ["0"]
      else
        md = v.match(/(.*)_(\d+)$/)
        if md.nil?
          portrev = 0
        else
          v = md[1]
          portrev = md[2]
        end
        result = v.scan(/[0-9]+|[a-zA-Z]+/)
      end
      return result,portrev
    end
  end
end
