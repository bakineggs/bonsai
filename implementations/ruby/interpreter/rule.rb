require File.dirname(__FILE__) + '/../../../parser/rule'
require File.dirname(__FILE__) + '/matching'

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

  def extend_ordered_matching condition_index, node, child_index, partial_matching
    if condition_index == conditions.length
      if child_index == node.children.length || !must_match_all_nodes?
        return [partial_matching]
      else
        return []
      end
    end

    matchings = []
    condition = conditions[condition_index]

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

    elsif condition.creates_node?
      matching = partial_matching + Matching.new(:modifications => [[:create, condition, node, child_index]])
      matchings += extend_ordered_matching condition_index + 1, node, child_index, matching

    else
      condition.matching_descendants(child, node).each do |_, descendant_parent, descendant|
        condition.matchings(descendant, descendant_parent, child_index, node).each do |matching|
          matchings += extend_ordered_matching condition_index + 1, node, child_index + 1, partial_matching + matching
          if condition.matches_multiple_nodes?
            matchings += extend_ordered_matching condition_index, node, child_index + 1, partial_matching + matching
          end
        end
      end
    end

    matchings
  end

  def unordered_matchings node
    extend_unordered_matching conditions, node, node.children, Matching.new
  end

  def extend_unordered_matching conditions, node, children, partial_matching
    return [partial_matching] if conditions.empty? && (children.empty? || !must_match_all_nodes?)
    return [] if conditions.empty?

    matchings = []
    condition = conditions.find(&:prevents_match?) || conditions.sample
    reduced_conditions = conditions.dup
    reduced_conditions.delete_at reduced_conditions.find_index {|c| c == condition}

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

    elsif condition.creates_node?
      matching = partial_matching + Matching.new(:modifications => [[:create, condition, node, 0]])
      matchings += extend_unordered_matching reduced_conditions, node, children, matching

    else
      children.each do |child|
        reduced_children = children.dup
        reduced_children.delete_at reduced_children.find_index {|c| c == child}
        condition.matching_descendants(child, node).each do |_, descendant_parent, descendant|
          condition.matchings(descendant, descendant_parent).each do |matching|
            matchings += extend_unordered_matching reduced_conditions, node, reduced_children, partial_matching + matching
            if condition.matches_multiple_nodes?
              matchings += extend_unordered_matching conditions, node, reduced_children, partial_matching + matching
            end
          end
        end
      end
    end

    matchings
  end
end
