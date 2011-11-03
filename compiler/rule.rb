require File.dirname(__FILE__) + '/condition'

class Rule
  attr_reader :conditions

  def initialize options = {}
    @conditions_are_ordered = options[:conditions_are_ordered]
    @must_match_all_nodes = options[:must_match_all_nodes]
    @conditions = options[:conditions]
  end

  def conditions_are_ordered?
    @conditions_are_ordered
  end

  def must_match_all_nodes?
    @must_match_all_nodes
  end

  def conditions_can_match_in_order?
    false
  end

  def conditions_can_match_out_of_order?
    false
  end

  def conditions_can_match_ordered_nodes_out_of_order?
    false
  end
end
