require File.dirname(__FILE__) + '/rule'

class Parser
  class Line < String
    attr_accessor :line_number

    def initialize line, line_number
      self.line_number = line_number
      super line
    end
  end

  def parse_rules program
    definitions = [[]]
    program.split("\n").each_with_index do |line, i|
      line.sub!(/ *#.*/, '')

      definitions.push [] if line == '' && !definitions.last.empty?
      next if line == ''

      definitions.last.push Parser::Line.new line, i + 1
    end
    definitions -= [[]]

    definitions.map do |definition|
      parse_rule definition
    end
  end

  def parse_rule definition
    Rule.new
  end
end

class ParseError
end
