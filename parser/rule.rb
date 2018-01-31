require_relative 'condition'
require_relative 'action_condition'

class Rule
  attr_reader :conditions, :action_condition, :definition

  def initialize options = {}
    @matches_unordered_children = !!options[:matches_unordered_children]
    @matches_ordered_children = !!options[:matches_ordered_children]
    @must_match_all_nodes = !!options[:must_match_all_nodes]
    @conditions = options[:conditions]
    @action_condition = options[:conditions].pop if @conditions.last.is_a? ActionCondition
    @definition = options[:definition]

    raise Error.new 'A rule must have an Array of Condition conditions' unless @conditions.is_a?(Array) && @conditions.all? {|condition| condition.is_a? Condition}
    raise Error.new 'A rule must have an Array of String definition' unless @definition.is_a?(Array) && @definition.all? {|line| line.is_a? String}
  end

  def matches_unordered_children?
    @matches_unordered_children
  end

  def matches_ordered_children?
    @matches_ordered_children
  end

  def must_match_all_nodes?
    @must_match_all_nodes
  end

  class Error < StandardError; end
end
