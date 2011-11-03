require File.dirname(__FILE__) + '/rule'

class Condition
  attr_reader :node_type, :child_rule, :value, :code_segment

  def initialize options = {}
    @node_type = options[:node_type]
    @child_rule = options[:child_rule]
    @creates_node = options[:creates_node]
    @removes_node = options[:removes_node]
    @prevents_match = options[:prevents_match]
    @matches_multiple_nodes = options[:matches_multiple_nodes]
    @value = options[:value]
    @code_segment = options[:code_segment]
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
    !creates_node? && !prevents_match? && !matches_multiple_nodes?
  end

  def matches_multiple_nodes?
    @matches_multiple_nodes
  end
end
