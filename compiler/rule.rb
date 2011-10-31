require File.dirname(__FILE__) + '/condition'

class Rule
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
