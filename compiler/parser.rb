require File.dirname(__FILE__) + '/rule'

class Parser
  class Line < String
    attr_accessor :line_number

    def initialize line, line_number
      self.line_number = line_number
      super line
    end
  end

  class Error < StandardError
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
      if definition.first.match /^  /
        raise Error, 'The first condition of a rule must be at the top level'
      end

      Rule.new :conditions => parse_conditions(definition)
    end
  end

  def parse_conditions lines, depth = 0
    return [] if lines.empty?

    if lines.first.match /^#{'  ' * depth}  /
      raise Error, 'Conditions must be at most 1 level below their parents'
    end

    conditions = [lines.shift]
    child_lines = []

    lines.each do |line|
      if line.match /^#{'  ' * depth}  /
        child_lines.push line
        next
      elsif line.match /^#{'  ' * depth} /
        raise Error, 'Conditions can not be in between levels'
      end

      conditions.push parse_condition(conditions.pop, depth, child_lines)
      conditions.push line
      child_lines = []
    end
    conditions.push parse_condition(conditions.pop, depth, child_lines)

    conditions
  end

  def parse_condition line, depth = 0, child_lines = []
    unless match = line.match(/^#{'  ' * depth}([!+-]?)([A-Za-z0-9 ]+):(:?)(=?)(\*?)$/)
      raise Error, 'Condition could not be parsed'
    end

    Condition.new({
      :creates_node => match[1] == '+',
      :removes_node => match[1] == '-',
      :prevents_match => match[1] == '!',
      :label => match[2],
      :matches_multiple_nodes => match[5],
      :child_rule => Rule.new({
        :conditions_are_ordered => match[3] == ':',
        :must_match_all_nodes => match[4] == '=',
        :conditions => parse_conditions(child_lines, depth + 1)
      })
    })
  end
end
