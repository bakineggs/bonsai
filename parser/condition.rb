class Condition
  attr_reader :label, :child_rule, :value, :variable

  def initialize options = {}
    @label = options[:label]
    @child_rule = options[:child_rule]
    @creates_node = options[:creates_node]
    @removes_node = options[:removes_node]
    @prevents_match = options[:prevents_match]
    @matches_descendants = options[:matches_descendants]
    @matches_multiple_nodes = options[:matches_multiple_nodes]
    @value = options[:value]
    @variable = options[:variable]

    raise Error.new 'A condition can not have both a value and a child rule' if @value && @child_rule

    raise Error.new 'A preventing condition in an unordered rule can not match multiple nodes' if !options[:parent_rule_is_ordered] && @prevents_match && @matches_multiple_nodes

    if options[:ancestor_creates]
      raise Error.new 'A creating condition can not have a descendant that is a creating condition' if @creates_node
      raise Error.new 'A creating condition can not have a descendant that is a removing condition' if @removes_node
      raise Error.new 'A creating condition can not have a descendant that is a preventing condition' if @prevents_match
      raise Error.new 'A creating condition can not have a descendant condition that matches descendant conditions' if @matches_descendants
      raise Error.new 'A creating condition can not have a descendant condition that matches multiple nodes' if @matches_multiple_nodes
      raise Error.new 'A creating condition can not have a descendant rule that must match all child nodes' if options[:parent_rule_must_match_all_nodes]
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
    !!@creates_node
  end

  def removes_node?
    !!@removes_node
  end

  def prevents_match?
    !!@prevents_match
  end

  def matches_descendants?
    !!@matches_descendants
  end

  def matches_multiple_nodes?
    !!@matches_multiple_nodes
  end

  class Error < StandardError; end
end
