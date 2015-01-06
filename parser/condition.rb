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
end
