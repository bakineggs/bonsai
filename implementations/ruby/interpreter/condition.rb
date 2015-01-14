require File.dirname(__FILE__) + '/../../../parser/condition'

class Condition
  def matches? node, check_descendants = true
    raise 'It does not make sense to ask if a creating condition matches a node' if creates_node?

    if label == '*' || label == node.label
      return true if value && value == node.value
      return true if child_rule && !child_rule.matchings(node).empty?
    end

    if check_descendants && matches_descendants? && node.children && node.children.any? {|child| matches? child}
      return true
    end

    false
  end
end
