require_relative 'node'

class Matching
  attr_reader :restriction, :modifications

  def initialize options = {}
    @variables = {}
    @restriction = simplify options.has_key?(:restriction) ? options[:restriction] : true
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
        simplify [:neq, restriction[1][1], restriction[1][2]]
      elsif restriction[1][0] == :neq
        simplify [:eq, restriction[1][1], restriction[1][2]]
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
      @variables[restriction[1]][:eq].all? {|node| restriction[2].equals_except_label? node}
    when :neq
      @variables[restriction[1]][:eq].all? {|node| !restriction[2].equals_except_label? node}
    when :and
      check(restriction[1]) && check(restriction[2])
    when :or
      check(restriction[1]) || check(restriction[2])
    else
      raise "Don't know how to check #{restriction.inspect}"
    end
  end
end
