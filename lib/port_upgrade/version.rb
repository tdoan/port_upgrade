module Ports
  class Version
    include Comparable
    attr_reader :parts
    def initialize(s)
      @parts = breakup_version(s)
    end

    def <=>(other)
      cmp = 0
      @parts.each_with_index do |p,i|
        #$stderr.puts "Sizes: #{p.size} #{other.parts[i].size}"
        p.each_with_index do |q,j|
          a = q
          b = other.parts[i][j]
          a = a.to_i if a =~ /^[0-9]+$/
          b = b.to_i if b =~ /^[0-9]+$/
          #$stderr.puts "#{a} <=> #{b}"
          cmp = a <=> b
          break if cmp != 0
        end
        break if cmp != 0
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
