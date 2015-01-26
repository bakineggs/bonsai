require_relative 'rule'

class Condition
  attr_reader :node_type, :child_rule, :value, :variable

  def initialize options = {}
    @node_type = options[:node_type]
    @child_rule = options[:child_rule]
    @creates_node = options[:creates_node]
    @removes_node = options[:removes_node]
    @prevents_match = options[:prevents_match]
    @matches_multiple_nodes = options[:matches_multiple_nodes]
    @value = options[:value]
    @variable = options[:variable]
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

  def must_match_a_node?
    can_match_a_node? && !prevents_match? && !matches_multiple_nodes?
  end

  def can_match_a_node?
    !creates_node?
  end

  def node_must_match_variable_value?
    variable && can_match_a_node?
  end

  def node_sets_variable_value?
    variable && must_match_a_node?
  end

  def has_value_set_by_variable?
    variable && creates_node?
  end

  def matches_multiple_nodes?
    @matches_multiple_nodes
  end

  def value_type
    if    value.is_a? Fixnum then :integer
    elsif value.is_a? Float  then :decimal
    elsif value.is_a? String then :string
    elsif value.nil?         then :none
    end
  end
end
