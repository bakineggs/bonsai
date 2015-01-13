require File.dirname(__FILE__) + '/../../../parser/rule'

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
        if condition.matches_descendants?
          # TODO: how to get matchings for descendant?
        end
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
          if condition.matches_descendants?
            # TODO: how to get matchings for descendant?
          end
          condition.child_rule.matchings(child).each do |child_matching|
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
      @variables = {}
      @restriction = simplify options[:restriction] || true
      @modifications = options[:modifications] || []
    end

    def restriction_met?
      @variables.each do |variable, hsh|
        if hsh[:eq].empty? && !hsh[:neq].empty?
          raise 'Can not check if a node is not equal to a variable that does not have a matching node'
        elsif hsh[:eq].all? {|node| node == hsh[:eq][0]} && hsh[:neq].all? {|node| node != hsh[:eq][0]}
          hsh[:node] = hsh[:eq][0]
        end
      end

      check restriction
    end

    def transform node
      old_node = node.dup
      (0...@modifications.length).to_a.reverse.each do |modification_index|
        modification = @modifications[modification_index]
        if modification[0] == :remove
          if modification[2].is_a? Node
            removal_index = modification[1].children.find_index {|child| child == modification[2]}
          elsif modification[2].is_a? Fixnum
            removal_index = modification[2]
          else
            raise "Don't know how to apply modification #{modification.inspect}"
          end
          raise 'Could not remove non-existent child' if !modification[1].children.delete_at removal_index
        elsif modification[0] == :create
          raise 'Tried to insert at invalid position' if modification[3] > modification[2].children.length
          modification[2].children.insert modification[3], create(modification[1])
        else
          raise "Don't know how to apply modification #{modification.inspect}"
        end
      end
      node != old_node
    end

    def + other
      restriction = [:and, @restriction, other.restriction]
      modifications = @modifications + other.modifications
      Matching.new :restriction => restriction, :modifications => modifications
    end

    private

    def create condition
      if condition.variable
        copy = @variables[condition.variable][:node].dup
        label = condition.label == '*' ? copy.label : condition.label
        Node.new label, copy.children, copy.children_are_ordered?, copy.value
      elsif condition.value
        Node.new condition.label, nil, nil, condition.value
      elsif condition.child_rule
        children = condition.child_rule.conditions.map {|c| create c}
        Node.new condition.label, children, condition.child_rule.conditions_are_ordered?, nil
      else
        raise "Don't know how to create node for #{condition.inspect}"
      end
    end

    def simplify restriction
      return restriction if [true, false].include? restriction
      case restriction[0]
      when :eq
        @variables[restriction[1]] ||= {:eq => [], :neq => []}
        @variables[restriction[1]][:eq].push restriction[2]
        restriction
      when :neq
        @variables[restriction[1]] ||= {:eq => [], :neq => []}
        @variables[restriction[1]][:neq].push restriction[2]
        restriction
      when :and
        r1 = simplify restriction[1]
        r2 = simplify restriction[2]
        if r1 == false || r2 == false
          false
        elsif r1 == true
          r2
        elsif r2 == true
          r1
        else
          [:and, r1, r2]
        end
      when :or
        r1 = simplify restriction[1]
        r2 = simplify restriction[2]
        if r1 == true || r2 == true
          true
        elsif r1 == false
          r2
        elsif r2 == false
          r1
        else
          [:or, r1, r2]
        end
      when :not
        if [true, false].include? restriction[1]
          !restriction[1]
        elsif restriction[1][0] == :eq
          [:neq, restriction[1][1], restriction[1][2]]
        elsif restriction[1][0] == :neq
          [:eq, restriction[1][1], restriction[1][2]]
        elsif restriction[1][0] == :not
          simplify restriction[1][1]
        elsif restriction[1][0] == :and
          simplify [:or, [:not, restriction[1][1]], [:not, restriction[1][2]]]
        elsif restriction[1][0] == :or
          simplify [:and, [:not, restriction[1][1]], [:not, restriction[1][2]]]
        end
      else
        raise "Don't know how to simplify #{restriction.inspect}"
      end
    end

    def check restriction
      return restriction if [true, false].include? restriction
      case restriction[0]
      when :eq
        restriction[2].equals_except_label? @variables[restriction[1]][:node]
      when :neq
        !restriction[2].equals_except_label?(@variables[restriction[1]][:node])
      when :and
        check(restriction[1]) && check(restriction[2])
      when :or
        check(restriction[1]) || check(restriction[2])
      else
        raise "Don't know how to check #{restriction.inspect}"
      end
    end
  end
end
