require_relative '../../../parser/rule'
require_relative 'matching'

class Array
  def combinations
    return self if length < 2
    later_combinations = self[1...length].combinations
    combinations = []
    self[0].each do |element|
      later_combinations.each do |combination|
        combinations.push [element] + combination
      end
    end
    combinations
  end

  def subsets
    subsets = [[]]
    (0...length).each do |i|
      reduced = dup
      reduced.delete_at i
      reduced.subsets.each do |subset|
        subsets.push subset + [self[i]]
      end
    end
    subsets
  end
end

class Rule
  def transform node
    matchings(node).select(&:restriction_met?).shuffle.any? do |matching|
      matching.transform node
    end
  end

  def matchings node
    if node.value && conditions.empty? && !conditions_are_ordered? && !must_match_all_nodes?
      [Matching.new]
    elsif node.value || conditions_are_ordered? != node.children_are_ordered?
      []
    elsif conditions_are_ordered?
      ordered_matchings node
    else
      unordered_matchings node
    end
  end

  private

  def ordered_matchings node
    if must_match_all_nodes?
      extend_ordered_matching 0, node, 0, Matching.new
    else
      (0..node.children.length).map do |i|
        extend_ordered_matching 0, node, i, Matching.new
      end.flatten
    end
  end

  def extend_ordered_matching condition_index, node, child_index, partial_matching, multi_matched = []
    if condition_index == conditions.length
      if child_index == node.children.length || !must_match_all_nodes?
        return [partial_matching]
      else
        return []
      end
    end

    condition = conditions[condition_index]

    if condition.creates_node?
      return extend_ordered_matching condition_index + 1, node, child_index, partial_matching + Matching.new(:modifications => [[:create, condition, node, child_index]])
    end

    matchings = []

    if condition.variable_matches_multiple_nodes?
      if condition.prevents_match?
        matchings += extend_ordered_matching condition_index + 1, node, child_index, partial_matching

        return matchings if child_index == node.children.length
        child = node.children[child_index]

        matching = partial_matching
        multi_matched.push condition.matching_descendants(child, node).map {|_, _, descendant| descendant}
        multi_matched.combinations.each do |neq_o|
          condition.matchings(neq_o.last, nil).each do |descendant_matching|
            matching += Matching.new :restriction => [:or, [:not, descendant_matching.restriction], [:neq_o, condition.variable, neq_o]]
          end
        end
        matchings += extend_ordered_matching condition_index, node, child_index + 1, matching, multi_matched
      else
        matchings += extend_ordered_matching condition_index + 1, node, child_index, partial_matching + Matching.new(:restriction => [:eq_o, condition.variable, multi_matched])

        return matchings if child_index == node.children.length
        child = node.children[child_index]

        condition.matching_descendants(child, node).each do |_, descendant_parent, descendant|
          condition.matchings(descendant, descendant_parent, child_index, node).each do |matching|
            matchings += extend_ordered_matching condition_index, node, child_index + 1, partial_matching + matching, multi_matched + [descendant]
          end
        end
      end

      return matchings
    end

    if condition.matches_multiple_nodes?
      matchings += extend_ordered_matching condition_index + 1, node, child_index, partial_matching
    end

    return matchings if child_index == node.children.length
    child = node.children[child_index]

    if condition.prevents_match?
      matching = partial_matching
      condition.matching_descendants(child, node).each do |_, _, descendant|
        condition.matchings(descendant, nil).each do |descendant_matching|
          matching += descendant_matching
        end
      end
      matchings += extend_ordered_matching condition_index + 1, node, child_index + 1, matching
      if condition.matches_multiple_nodes?
        matchings += extend_ordered_matching condition_index, node, child_index + 1, matching
      end

    else
      condition.matching_descendants(child, node).each do |_, descendant_parent, descendant|
        condition.matchings(descendant, descendant_parent, child_index, node).each do |matching|
          if condition.matches_multiple_nodes?
            matchings += extend_ordered_matching condition_index, node, child_index + 1, partial_matching + matching
          else
            matchings += extend_ordered_matching condition_index + 1, node, child_index + 1, partial_matching + matching
          end
        end
      end
    end

    matchings
  end

  def unordered_matchings node
    extend_unordered_matching conditions, node, node.children, Matching.new
  end

  def extend_unordered_matching conditions, node, children, partial_matching, condition = nil, multi_matched = []
    return [partial_matching] if conditions.empty? && (children.empty? || !must_match_all_nodes?)
    return [] if conditions.empty?

    condition ||= conditions.find(&:prevents_match?) || conditions.sample
    reduced_conditions = conditions.dup
    reduced_conditions.delete_at reduced_conditions.find_index {|c| c == condition}

    if condition.creates_node?
      return extend_unordered_matching reduced_conditions, node, children, partial_matching + Matching.new(:modifications => [[:create, condition, node, 0]])
    end

    matchings = []

    if condition.variable_matches_multiple_nodes?
      if condition.prevents_match?
        matching = partial_matching
        matching_descendants = children.map {|child| condition.matching_descendants(child, node).map {|_, _, descendant| descendant}}.flatten
        matching_descendants.subsets.each do |neq_u|
          combined_descendant_matching = Matching.new
          neq_u.map {|descendant| condition.matchings(descendant, nil)}.flatten.each do |descendant_matching|
            combined_descendant_matching += descendant_matching
          end
          matching += Matching.new :restriction => [:or, [:not, combined_descendant_matching.restriction], [:neq_u, condition.variable, neq_u.sort]]
        end
        matchings += extend_unordered_matching reduced_conditions, node, children, matching
      else
        matchings += extend_unordered_matching reduced_conditions, node, children, partial_matching + Matching.new(:restriction => [:eq_u, condition.variable, multi_matched])
        children.each do |child|
          reduced_children = children.dup
          reduced_children.delete_at reduced_children.find_index {|c| c == child}
          condition.matching_descendants(child, node).each do |_, descendant_parent, descendant|
            condition.matchings(descendant, descendant_parent).each do |matching|
              matchings += extend_unordered_matching conditions, node, reduced_children, partial_matching + matching, condition, multi_matched + [descendant]
            end
          end
        end
      end

      return matchings
    end

    if condition.matches_multiple_nodes?
      matchings += extend_unordered_matching reduced_conditions, node, children, partial_matching
    end

    if condition.prevents_match?
      matching = partial_matching
      children.each do |child|
        condition.matching_descendants(child, node).each do |_, _, descendant|
          condition.matchings(descendant, nil).each do |descendant_matching|
            matching += descendant_matching
          end
        end
      end
      matchings += extend_unordered_matching reduced_conditions, node, children, matching

    else
      children.each do |child|
        reduced_children = children.dup
        reduced_children.delete_at reduced_children.find_index {|c| c == child}
        condition.matching_descendants(child, node).each do |_, descendant_parent, descendant|
          condition.matchings(descendant, descendant_parent).each do |matching|
            if condition.matches_multiple_nodes?
              matchings += extend_unordered_matching conditions, node, reduced_children, partial_matching + matching
            else
              matchings += extend_unordered_matching reduced_conditions, node, reduced_children, partial_matching + matching
            end
          end
        end
      end
    end

    matchings
  end
end
