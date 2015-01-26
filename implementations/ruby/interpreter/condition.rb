require File.dirname(__FILE__) + '/../../../parser/condition'
require File.dirname(__FILE__) + '/matching'

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

  def matchings node, parent, removal_index = nil, removal_index_parent = nil
    if child_rule
      matchings = child_rule.matchings node
    else
      matchings = [Matching.new]
    end

    matchings.map! do |matching|
      matching += Matching.new :restriction => [:eq, variable, node] if variable
      matching = Matching.new :restriction => [:not, matching.restriction] if prevents_match?
      matching
    end

    if removes_node?
      if parent.children_are_ordered?
        if removal_index && parent == removal_index_parent
          removal_args = [removal_index]
        else
          removal_args = []
          parent.children.each_with_index do |child, index|
            removal_args.push index if child == node
          end
        end
      else
        removal_args = [node]
      end
      matchings.map! do |matching|
        removal_args.map do |removal_arg|
          matching + Matching.new(:modifications => [[:remove, parent, removal_arg]])
        end
      end.flatten!
    end

    matchings
  end
end
