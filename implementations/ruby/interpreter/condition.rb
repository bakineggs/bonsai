require File.dirname(__FILE__) + '/../../../parser/condition'

class Condition
  def matches? node
    raise 'It does not make sense to ask if a creating condition matches a node' if creates_node?

    if label == '*' || label == node.label
      return true if value && value == node.value
      return true if child_rule && !child_rule.matchings(node).empty?
    end

    false
  end

  def matching_descendants node, parent
    if matches_descendants?
      node.descendants(parent).select {|_, _, descendant| matches? descendant}
    elsif matches? node
      [[nil, parent, node]]
    else
      []
    end
  end
end
