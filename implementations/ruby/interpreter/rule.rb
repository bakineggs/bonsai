require File.dirname(__FILE__) + '/../../../parser/rule'

class Rule
  def transform node
    matchings(node).select(&:restriction_met?).shuffle.any? do |matching|
      matching.transform node
    end
  end

  def matchings node
    if node.value && !conditions_are_ordered? && !must_match_all_nodes?
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
        elsif condition.variable
          matching = partial_matching + Matching.new(:restriction => [:neq, condition.variable, child])
          matchings += extend_ordered_matching condition_index + 1, node, child_index + 1, matching
          if condition.matches_multiple_nodes?
            matchings += extend_ordered_matching condition_index, node, child_index + 1, matching
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
      matching += Matching.new :modifications => [[:remove, node, child_index]] if condition.removes_node?
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
    extend_unordered_matching conditions, node, node.children, Matching.new
  end

  def extend_unordered_matching conditions, node, children, partial_matching
    return [partial_matching] if conditions.empty? && (children.empty? || !must_match_all_nodes?)
    return [] if conditions.empty?

    matchings = []
    condition = conditions.sample
    reduced_conditions = conditions.dup
    reduced_conditions.delete_at reduced_conditions.find_index {|c| c == condition}

    if condition.matches_multiple_nodes?
      matchings += extend_unordered_matching reduced_conditions, node, children, partial_matching
    end

    if condition.prevents_match?
      matching = partial_matching
      children.each do |child|
        next unless condition.matches? child
        if condition.child_rule
          condition.child_rule.matchings(child).each do |child_matching|
            if condition.variable
              matching += Matching.new :restriction => [:or, [:neq, condition.variable, child], [:not, child_matching.restriction]]
            else
              matching += Matching.new :restriction => [:not, child_matching.restriction]
            end
          end
        elsif condition.variable
          matching += Matching.new :restriction => [:neq, condition.variable, child]
        else
          matching += Matching.new :restriction => false
        end
      end
      matchings += extend_unordered_matching reduced_conditions, node, children, matching

    elsif condition.creates_node?
      matching = partial_matching + Matching.new(:modifications => [[:create, condition, node, 0]])
      matchings += extend_unordered_matching reduced_conditions, node, children, matching

    else
      children.each do |child|
        next unless condition.matches? child
        matching = partial_matching
        matching += Matching.new :modifications => [[:remove, node, child]] if condition.removes_node?
        matching += Matching.new :restriction => [:eq, condition.variable, child] if condition.variable
        reduced_children = children.dup
        reduced_children.delete_at reduced_children.find_index {|c| c == child}
        if condition.child_rule
          condition.child_rule.matchings(node).each do |child_matching|
            matchings += extend_unordered_matching reduced_conditions, node, reduced_children, matching + child_matching
            if condition.matches_multiple_nodes?
              matchings += extend_unordered_matching conditions, node, reduced_children, matching + child_matching
            end
          end
        else
          matchings += extend_unordered_matching reduced_conditions, node, reduced_children, matching
          if condition.matches_multiple_nodes?
            matchings += extend_unordered_matching conditions, node, reduced_children, matching
          end
        end
      end

    end

    matchings
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
