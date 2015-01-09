require File.dirname(__FILE__) + '/../../../parser/condition'

class Condition
  def matches? node
    raise 'It does not make sense to ask if a creating condition matches a node' if creates_node?

    if label == '*' || label == node.label
      return true if value && value == node.value
      return true if child_rule && child_rule.matches?(node)
    end

    if matches_descendants? && node.children.any? {|child| matches_node? child}
      return true
    end

    false
  end
end
