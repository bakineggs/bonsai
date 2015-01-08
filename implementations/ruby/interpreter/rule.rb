require File.dirname(__FILE__) + '/../../../parser/rule'

class Rule
  def transform node
    return false if node.value
    return false if conditions_are_ordered? != node.children_are_ordered?

    matchings = matchings(node).select &:restriction_met?
    matchings.shuffle.any? {|matching| matching.transform node}
  end

  def matchings node
    if conditions_are_ordered?
      ordered_matchings node
    else
      unordered_matchings node
    end
  end

  private

  def ordered_matchings node
    if must_match_all_conditions?
      extend_ordered_matching 0, node, 0, Matching.new
    else
      (0...node.children.length).map do |i|
        extend_ordered_matching 0, node, i, Matching.new
      end.flatten
    end
  end

  def extend_ordered_matching condition_index, node, child_index, partial_matching
    if condition_index == conditions.length
      if child_index == node.children.length || !must_match_all_conditions?
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
    child = node.children[condition_index]

    if condition.prevents_match?
      if condition.matches? child
        if condition.child_rule
          condition.child_rule.matchings(node).each do |child_matching|
            if condition.variable
              matching = partial_matching + Matching.new(:restriction => [:or, [:neq, condition.variable, child], [:not, child_matching.restriction]])
            else
              matching = partial_matching + Matching.new(:restriction => [:not, child_matching.restriction])
            end
            matchings += extend_ordered_matching condition_index + 1, node, child_index + 1, matching
            if condition.matches_multiple_nodes?
              matchings += extend_ordered_matching condition_index, node, child_index + 1, matching
            end
          end
        end
      else
        matchings += extend_ordered_matching condition_index + 1, node, child_index + 1, partial_matching
      end

    elsif condition.creates_node?
      matching = partial_matching + Matching.new(:modifications => [[:create, condition, node, child_index]])
      matchings += extend_ordered_matching condition_index + 1, node, child_index, matching

    elsif condition.matches? child
      matching = partial_matching
      matching += Matching.new :modifications => [[:remove, node, child_index]]
      matching += Matching.new :restriction => [:eq, condition.variable, child] if condition.variable
      if condition.child_rule
        condition.child_rule.matchings(node).each do |child_matching|
          matchings += extend_ordered_matching condition_index + 1, node, child_index + 1, matching + child_matching
          if condition.matches_multiple_nodes?
            matchings += extend_ordered_matching condition_index, node, child_index + 1, matching + child_matching
          end
        end
      else
        matchings += extend_ordered_matching condition_index + 1, node, child_index + 1, matching
        if condition.matches_multiple_nodes?
          matchings += extend_ordered_matching condition_index, node, child_index + 1, matching
        end
      end

    end

    matchings
  end

  def unordered_matchings node
    [] # TODO
  end

  class Matching
    attr_reader :restriction, :modifications

    def initialize options = {}
      @restriction = options[:restriction]
      @modifications = options[:modifications] || []
    end

    def restriction_met?
      false # TODO
    end

    def transform node
      false # TODO
    end

    def + other
      restriction = [:and, @restriction, other.restriction]
      modifications = @modifications + other.modifications
      Matching.new :restriction => restriction, :modifications => modifications
    end
  end
end
