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
    attr_accessor :line

    def initialize message, line
      self.line = line
      super message
    end
  end

  def parse_program program
    lines = []
    program.split("\n").each_with_index do |line, i|
      line.sub!(/ *#.*/, '')
      lines.push Line.new line, i + 1
    end

    if end_of_header = lines.index("%}")
      start_of_header = lines.index "%{"
      raise Error.new 'Expected start of header to come before end of header', lines[end_of_header] unless start_of_header && start_of_header < end_of_header

      header = lines[start_of_header+1...end_of_header]
      rule_lines = lines[0...start_of_header] + lines[end_of_header+1..-1]
    else
      header = []
      rule_lines = lines
    end

    definitions = [[]]
    rule_lines.each do |line|
      definitions.push [] if line == '' && !definitions.last.empty?
      next if line == ''
      definitions.last.push line
    end

    {
      :header => header.join("\n"),
      :rules => parse_rules(definitions - [[]])
    }
  end

  def parse_rules definitions
    definitions.map do |definition|
      if definition.first.match /^  /
        raise Error.new 'The first condition of a rule must be at the top level', definition.first
      end

      Rule.new :top_level => true, :conditions => parse_conditions(definition)
    end
  end

  def parse_conditions lines, depth = 0
    return [] if lines.empty?

    if lines.first.match /^#{'  ' * depth}  /
      raise Error.new 'Conditions must be at most 1 level below their parents', lines.first
    end

    conditions = [lines.shift]
    child_lines = []

    lines.each do |line|
      if line.match /^#{'  ' * depth}  /
        child_lines.push line
        next
      elsif line.match /^#{'  ' * depth} /
        raise Error.new 'Conditions can not be in between levels', line
      end

      conditions.push parse_condition(conditions.pop, depth, child_lines)
      conditions.push line
      child_lines = []
    end
    conditions.push parse_condition(conditions.pop, depth, child_lines)

    conditions
  end

  def parse_condition line, depth = 0, child_lines = []
    unless match = line.match(/^#{'  ' * depth}([!+-])?([A-Za-z0-9 ]+|\^):(:)?(=)?(\*)?( (-?\d+|(-?\d+\.\d+)|< (.*)|([A-Za-z]+)))?$/)
      raise Error.new 'Condition could not be parsed', line
    end

    if match[10]
      variable = match[10]
    elsif match[9]
      code_segment = match[9]
    elsif match[8]
      value = match[8].to_f
    elsif match[7]
      value = match[7].to_i
    end

    Condition.new({
      :creates_node => match[1] == '+',
      :removes_node => match[1] == '-',
      :prevents_match => match[1] == '!',
      :node_type => match[2] == '^' ? :root : match[2],
      :matches_multiple_nodes => match[5] == '*',
      :value => value,
      :code_segment => code_segment,
      :variable => variable,
      :child_rule => Rule.new({
        :conditions_are_ordered => match[3] == ':',
        :must_match_all_nodes => match[4] == '=',
        :conditions => parse_conditions(child_lines, depth + 1)
      })
    })
  end
end
