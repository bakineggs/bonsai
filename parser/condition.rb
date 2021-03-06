class Condition
  attr_reader :label, :child_rule, :value, :variable

  def initialize options = {}
    @label = options[:label]
    @child_rule = options[:child_rule]
    @creates_node = !!options[:creates_node]
    @removes_node = !!options[:removes_node]
    @prevents_match = !!options[:prevents_match]
    @matches_descendants = !!options[:matches_descendants]
    @matches_multiple_nodes = !!options[:matches_multiple_nodes]
    @value = options[:value]
    @variable = options[:variable]
    @variable_matches_labels = !!options[:variable_matches_labels]
    @variable_matches_multiple_nodes = !!options[:variable_matches_multiple_nodes]

    raise Error.new 'A condition must have a non-empty String label' unless @label.is_a?(String) && !@label.empty?
    raise Error.new 'A condition must have a Rule child_rule' unless @child_rule.nil? || @child_rule.is_a?(Rule)
    raise Error.new 'A condition must have a Fixnum, Float, or String value' unless @value.nil? || [Fixnum, Float, String].any? {|t| @value.is_a? t}
    raise Error.new 'A condition must have a String variable' unless @variable.nil? || @variable.is_a?(String)

    raise Error.new 'A condition must have either a child rule or a value' unless @child_rule || @value

    raise Error.new 'A condition can not have both a value and a child rule' if @value && @child_rule
    raise Error.new 'A condition can not have both a value and a variable' if @value && @variable

    raise Error.new 'A condition can not have a variable that matches labels without a variable' if @variable_matches_labels && !@variable
    raise Error.new 'A condition can not have a variable that matches labels without a wildcard label' if @variable_matches_labels && @label != '*'

    raise Error.new 'A condition can not have a variable that matches multiple nodes without matching multiple nodes' if @variable_matches_multiple_nodes && !@matches_multiple_nodes
    raise Error.new 'A condition can not have a variable that matches multiple nodes without a variable' if @variable_matches_multiple_nodes && !@variable

    raise Error.new 'A preventing condition in an unordered rule can not match multiple nodes unless it has a variable that matches multiple nodes' if options[:parent_rule_matches_unordered_conditions] && @prevents_match && @matches_multiple_nodes && !@variable_matches_multiple_nodes

    if @creates_node
      raise Error.new 'A creating condition can not match descendant conditions' if @matches_descendants
      raise Error.new 'A creating condition can not match multiple nodes without a variable that matches multiple nodes' if @matches_multiple_nodes && !@variable_matches_multiple_nodes
      raise Error.new 'A creating condition can not have a child rule that must match all child nodes' if @child_rule && @child_rule.must_match_all_nodes?
      raise Error.new 'A creating condition with a variable can not have a child rule' if @variable && @child_rule && !@child_rule.conditions.empty?
    end

    if options[:ancestor_creates]
      raise Error.new 'A creating condition can not have a descendant that is a creating condition' if @creates_node
      raise Error.new 'A creating condition can not have a descendant that is a removing condition' if @removes_node
      raise Error.new 'A creating condition can not have a descendant that is a preventing condition' if @prevents_match
      raise Error.new 'A creating condition can not have a descendant condition that matches descendant conditions' if @matches_descendants
      raise Error.new 'A creating condition can not have a descendant condition that matches multiple nodes without a variable that matches multiple nodes' if @matches_multiple_nodes && !@variable_matches_multiple_nodes
      raise Error.new 'A creating condition can not have a descendant rule that must match all child nodes' if options[:parent_rule_must_match_all_nodes]
      raise Error.new 'A creating condition can not have a descendant condition with a variable that has a child rule' if @variable && @child_rule && !@child_rule.conditions.empty?
    end

    if options[:ancestor_removes]
      raise Error.new 'A removing condition can not have a descendant that is a creating condition' if @creates_node
      raise Error.new 'A removing condition can not have a descendant that is a removing condition' if @removes_node
    end

    if options[:ancestor_prevents]
      raise Error.new 'A preventing condition can not have a descendant that is a creating condition' if @creates_node
      raise Error.new 'A preventing condition can not have a descendant that is a removing condition' if @removes_node
    end
  end

  def creates_node?
    @creates_node
  end

  def removes_node?
    @removes_node
  end

  def prevents_match?
    @prevents_match
  end

  def matches_descendants?
    @matches_descendants
  end

  def matches_multiple_nodes?
    @matches_multiple_nodes
  end

  def variable_matches_labels?
    @variable_matches_labels
  end

  def variable_matches_multiple_nodes?
    @variable_matches_multiple_nodes
  end

  class Error < StandardError; end
end
