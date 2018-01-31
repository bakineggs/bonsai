require_relative 'rule'
require_relative 'condition'
require_relative 'action_condition'

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

  # TODO: a creating condition can not have a descendant rule that matches both unordered and ordered children unless that rule's condition matches a variable that matches both unordered and ordered children
  def parse_rule definition, depth = 0, options = {:matches_unordered_children => true, :matches_ordered_children => true}
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
      :parent_rule_matches_unordered_children => options[:matches_unordered_children],
      :parent_rule_matches_ordered_children => options[:matches_ordered_children],
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
        :parent_rule_matches_unordered_children => options[:parent_rule_matches_unordered_children],
        :parent_rule_matches_ordered_children => options[:parent_rule_matches_ordered_children],
        :parent_rule_must_match_all_nodes => options[:parent_rule_must_match_all_nodes]
      condition_line = line
      child_lines = []
    end

    if condition_line == '$:'
      conditions.push ActionCondition.new child_lines
    else
      conditions.push parse_condition condition_line, depth, child_lines,
        :ancestor_creates => options[:ancestor_creates],
        :ancestor_removes => options[:ancestor_removes],
        :ancestor_prevents => options[:ancestor_prevents],
        :parent_rule_matches_unordered_children => options[:parent_rule_matches_unordered_children],
        :parent_rule_matches_ordered_children => options[:parent_rule_matches_ordered_children],
        :parent_rule_must_match_all_nodes => options[:parent_rule_must_match_all_nodes]
    end

    conditions
  end

  def parse_condition line, depth = 0, child_lines = [], options = {}
    if line.match /^#{'  ' * depth}\$:$/
      raise Error.new 'An action condition must be the last condition of the top level rule', line
    end

    unless match = line.match(/^#{'  ' * depth}([!+-])?(\.\.\.)?([A-Za-z0-9 ]+|\^|\*):([:.])?(=)?(\*)?( (-?\d+|(-?\d+\.\d+)|"(.*)"|((=?)([A-Za-z][A-Za-z0-9 ]*))|((=?)\[([A-Za-z][A-Za-z0-9 ]*)\])))?$/)
      raise Error.new 'Condition could not be parsed', line
    end

    if match[14]
      variable = match[16]
      variable_matches_labels = match[15] == '='
      variable_matches_multiple_nodes = true
    elsif match[11]
      variable = match[13]
      variable_matches_labels = match[12] == '='
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
      :variable_matches_labels => variable_matches_labels,
      :variable_matches_multiple_nodes => variable_matches_multiple_nodes,
      :child_rule => value && child_lines.empty? ? nil : parse_rule(child_lines, depth + 1,
        :matches_unordered_children => match[4].nil? || match[4] == '.',
        :matches_ordered_children => match[4] == ':' || match[4] == '.',
        :must_match_all_nodes => match[5] == '=',
        :ancestor_creates => options[:ancestor_creates] || match[1] == '+',
        :ancestor_removes => options[:ancestor_removes] || match[1] == '-',
        :ancestor_prevents => options[:ancestor_prevents] || match[1] == '!'
      ),
      :ancestor_creates => options[:ancestor_creates],
      :ancestor_removes => options[:ancestor_removes],
      :ancestor_prevents => options[:ancestor_prevents],
      :parent_rule_matches_unordered_children => options[:parent_rule_matches_unordered_children],
      :parent_rule_matches_ordered_children => options[:parent_rule_matches_ordered_children],
      :parent_rule_must_match_all_nodes => options[:parent_rule_must_match_all_nodes]
    })
  rescue Rule::Error => e
    raise Error.new e.message, line
  rescue Condition::Error => e
    raise Error.new e.message, line
  end
end
