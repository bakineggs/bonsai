require_relative 'rule'
require_relative 'condition'

class Parser
  class Line < String
    attr_reader :line_number

    def initialize line, line_number
      @line_number = line_number
      super line
    end
  end

  class Error < StandardError
    attr_reader :line

    def initialize message, line
      @line = line
      super message
    end
  end

  def parse program
    lines = []
    program.split("\n").each_with_index do |line, i|
      next if line =~ /^ *#.*$/
      line.sub!(/ *#.*$/, '')
      lines.push Line.new line, i + 1
    end

    rules = []
    definition = []
    lines.each do |line|
      if line != ''
        definition.push line
      elsif !definition.empty?
        rules.push parse_rule definition
        definition = []
      end
    end
    rules.push parse_rule definition unless definition.empty?

    rules
  end

  private

  def parse_rule definition, depth = 0, options = {}
    options[:definition] = definition.clone

    if !definition.empty? && definition.first.match(/^#{'  ' * depth}  /)
      if depth == 0
        raise Error.new 'The first condition of a rule must be at the top level', definition.first
      else
        raise Error.new 'Conditions must be at most 1 level below their parents', definition.first
      end
    end

    options[:conditions] = parse_conditions definition, depth,
      :ancestor_creates => options[:ancestor_creates],
      :ancestor_removes => options[:ancestor_removes],
      :ancestor_prevents => options[:ancestor_prevents],
      :parent_rule_is_ordered => options[:conditions_are_ordered],
      :parent_rule_must_match_all_nodes => options[:must_match_all_nodes]

    Rule.new options
  end

  def parse_conditions lines, depth = 0, options = {}
    return [] if lines.empty?

    conditions = []
    condition_line = lines.shift
    child_lines = []

    lines.each do |line|
      if line.match /^#{'  ' * depth}  /
        child_lines.push line
        next
      elsif line.match /^#{'  ' * depth} /
        raise Error.new 'Conditions can not be in between levels', line
      end

      conditions.push parse_condition condition_line, depth, child_lines,
        :ancestor_creates => options[:ancestor_creates],
        :ancestor_removes => options[:ancestor_removes],
        :ancestor_prevents => options[:ancestor_prevents],
        :parent_rule_is_ordered => options[:parent_rule_is_ordered],
        :parent_rule_must_match_all_nodes => options[:parent_rule_must_match_all_nodes]
      condition_line = line
      child_lines = []
    end
    conditions.push parse_condition condition_line, depth, child_lines,
      :ancestor_creates => options[:ancestor_creates],
      :ancestor_removes => options[:ancestor_removes],
      :ancestor_prevents => options[:ancestor_prevents],
      :parent_rule_is_ordered => options[:parent_rule_is_ordered],
      :parent_rule_must_match_all_nodes => options[:parent_rule_must_match_all_nodes]

    conditions
  end

  def parse_condition line, depth = 0, child_lines = [], options = {}
    unless match = line.match(/^#{'  ' * depth}([!+-])?(\.\.\.)?([A-Za-z0-9 ]+|\^|\*):(:)?(=)?(\*)?( (-?\d+|(-?\d+\.\d+)|"(.*)"|([A-Za-z][A-Za-z0-9 ]*)|(\[([A-Za-z][A-Za-z0-9 ]*)\])))?$/)
      raise Error.new 'Condition could not be parsed', line
    end

    if match[13]
      variable = match[13]
    elsif match[11]
      variable = match[11]
    elsif match[10]
      value = match[10]
    elsif match[9]
      value = match[9].to_f
    elsif match[8]
      value = match[8].to_i
    end

    Condition.new({
      :creates_node => match[1] == '+',
      :removes_node => match[1] == '-',
      :prevents_match => match[1] == '!',
      :label => match[3],
      :matches_descendants => match[2] == '...',
      :matches_multiple_nodes => match[6] == '*',
      :value => value,
      :variable => variable,
      :variable_matches_multiple_nodes => match[12] != nil,
      :child_rule => value && child_lines.empty? ? nil : parse_rule(child_lines, depth + 1,
        :conditions_are_ordered => match[4] == ':',
        :must_match_all_nodes => match[5] == '=',
        :ancestor_creates => options[:ancestor_creates] || match[1] == '+',
        :ancestor_removes => options[:ancestor_removes] || match[1] == '-',
        :ancestor_prevents => options[:ancestor_prevents] || match[1] == '!'
      ),
      :ancestor_creates => options[:ancestor_creates],
      :ancestor_removes => options[:ancestor_removes],
      :ancestor_prevents => options[:ancestor_prevents],
      :parent_rule_is_ordered => options[:parent_rule_is_ordered],
      :parent_rule_must_match_all_nodes => options[:parent_rule_must_match_all_nodes]
    })
  rescue Rule::Error => e
    raise Error.new e.message, line
  rescue Condition::Error => e
    raise Error.new e.message, line
  end
end
