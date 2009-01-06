module Ports
  class Version
    include Comparable
    attr_reader :parts
    def initialize(s)
      @parts = breakup_version(s)
    end

    def <=>(other)
      $stderr.puts("self: #{@parts.inspect}") if $DEBUG
      $stderr.puts("other: #{other.parts.inspect}") if $DEBUG
      cmp = 0
      numparts = @parts.size>other.parts.size ? @parts.size : other.parts.size
      0.upto(numparts-1) do |i|
        p = i>=@parts.size ? ["-1"] : @parts[i]
        q = i>=other.parts.size ? ["-1"] : other.parts[i]
        numsubparts = p.size>q.size ? p.size : q.size
        0.upto(numsubparts-1) do |j|
          r = j>=p.size ? "-1" : p[j]
          s = j>=q.size ? "-1" : q[j]

          $stderr.puts("p of #{j}: #{r}") if $DEBUG
          $stderr.puts("q of #{j}: #{s}") if $DEBUG
          a = r =~ /^-?[0-9]+$/ ? r.to_i : r
          b = s =~ /^-?[0-9]+$/ ? s.to_i : s
          $stderr.puts "#{a.inspect} <=> #{b.inspect}" if $DEBUG
          if a.instance_of?(b.class)
            cmp = a <=> b
          else
            $stderr.puts "Can't compare different classes #{a.class.to_s} <=> #{b.class.to_s}" if $DEBUG
            cmp = 0
          end
          return cmp if cmp != 0
        end
        return cmp if cmp != 0
      end
      cmp
    end

    private
    def get_state(c)
      case c
      when /[0-9]/
        state = 'd'
      else
        state = 'o'
      end
    end

    def subparts(s)
      state = get_state(s[0,1])
      #puts "State: #{state}"
      parts = []
      part = ""
      s.each_char do |c|
        newstate = get_state(c)
        case newstate
        when state
          part << c
        else
          parts << part #[part,state]
          part = ""
          part << c
          state = newstate
        end
      end
      parts << part #[part,state]
      parts
    end

    def breakup_version(v)
      raise "Bad input to version; not String" unless v.is_a?(String)
      if v =~ /\[[^\]]+\]/
        $stderr.puts "code version: #{v}"
        result = ["0"]
      else
        result = []
        v.split(/[-_.]/).each do |part|
          result << subparts(part)
        end
      end
      result
    end
  end
end
