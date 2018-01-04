require_relative 'node'

class Matching
  attr_reader :restriction, :modifications

  def initialize options = {}
    @variables = {}
    @restriction = simplify options.has_key?(:restriction) ? options[:restriction] : true
    @modifications = options[:modifications] || []
  end

  def restriction_met?
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
        modification[2].children.insert modification[3], *create(modification[1])
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
    raise "Can't have a creating condition with a variable that does not match anything" if condition.variable && (@variables[condition.variable].nil? || (@variables[condition.variable][:eq].empty? && @variables[condition.variable][:value].nil?))

    if condition.variable_matches_multiple_nodes?
      @variables[condition.variable][:eq].sample.map(&:dup).map do |copy|
        label = condition.label == '*' ? copy.label : condition.label
        Node.new label, copy.children, copy.children_are_ordered?, copy.value
      end
    elsif condition.variable && !@variables[condition.variable][:eq].empty?
      copy = @variables[condition.variable][:eq].sample.dup
      label = condition.label == '*' ? copy.label : condition.label
      [Node.new(label, copy.children, copy.children_are_ordered?, copy.value)]
    elsif condition.variable
      value = @variables[condition.variable][:value]
      value = value.to_i if value.to_i == value
      [Node.new(condition.label, nil, nil, value)]
    elsif condition.value
      [Node.new(condition.label, nil, nil, condition.value)]
    elsif condition.child_rule
      children = condition.child_rule.conditions.map {|c| create c}.flatten
      [Node.new(condition.label, children, condition.child_rule.conditions_are_ordered?, nil)]
    else
      raise "Don't know how to create node for #{condition.inspect}"
    end
  end

  def simplify restriction
    return restriction if [true, false].include? restriction
    case restriction[0]
    when :eq
      @variables[restriction[1]] ||= {:eq => [], :matches_labels => restriction[3], :computations => []}
      @variables[restriction[1]][:matches_labels] = restriction[3] if @variables[restriction[1]][:matches_labels].nil?
      raise "Can't have the same variable match single nodes and multiple nodes" if @variables[restriction[1]][:multi]
      raise "Can't have the same variable match labels and not match labels" if @variables[restriction[1]][:matches_labels] != restriction[3]
      @variables[restriction[1]][:eq].push restriction[2]
      restriction
    when :neq
      @variables[restriction[1]] ||= {:eq => [], :matches_labels => restriction[3], :computations => []}
      @variables[restriction[1]][:matches_labels] = restriction[3] if @variables[restriction[1]][:matches_labels].nil?
      raise "Can't have the same variable match single nodes and multiple nodes" if @variables[restriction[1]][:multi]
      raise "Can't have the same variable match labels and not match labels" if @variables[restriction[1]][:matches_labels] != restriction[3]
      restriction
    when :eq_o
      @variables[restriction[1]] ||= {:multi => true, :ordered => true, :eq => [], :matches_labels => restriction[3], :computations => []}
      @variables[restriction[1]][:ordered] = true if @variables[restriction[1]][:ordered].nil?
      @variables[restriction[1]][:matches_labels] = restriction[3] if @variables[restriction[1]][:matches_labels].nil?
      raise "Can't have the same variable match single nodes and multiple nodes" unless @variables[restriction[1]][:multi]
      raise "Can't have the same variable match multiple ordered nodes and multiple unordered nodes" unless @variables[restriction[1]][:ordered]
      raise "Can't have the same variable match labels and not match labels" if @variables[restriction[1]][:matches_labels] != restriction[3]
      @variables[restriction[1]][:eq].push restriction[2]
      restriction
    when :neq_o
      @variables[restriction[1]] ||= {:multi => true, :ordered => true, :eq => [], :matches_labels => restriction[3], :computations => []}
      @variables[restriction[1]][:ordered] = true if @variables[restriction[1]][:ordered].nil?
      @variables[restriction[1]][:matches_labels] = restriction[3] if @variables[restriction[1]][:matches_labels].nil?
      raise "Can't have the same variable match single nodes and multiple nodes" unless @variables[restriction[1]][:multi]
      raise "Can't have the same variable match multiple ordered nodes and multiple unordered nodes" unless @variables[restriction[1]][:ordered]
      raise "Can't have the same variable match labels and not match labels" if @variables[restriction[1]][:matches_labels] != restriction[3]
      restriction
    when :eq_u
      @variables[restriction[1]] ||= {:multi => true, :ordered => false, :eq => [], :matches_labels => restriction[3], :computations => []}
      @variables[restriction[1]][:ordered] = false if @variables[restriction[1]][:ordered].nil?
      @variables[restriction[1]][:matches_labels] = restriction[3] if @variables[restriction[1]][:matches_labels].nil?
      raise "Can't have the same variable match single nodes and multiple nodes" unless @variables[restriction[1]][:multi]
      raise "Can't have the same variable match multiple ordered nodes and multiple unordered nodes" if @variables[restriction[1]][:ordered]
      raise "Can't have the same variable match labels and not match labels" if @variables[restriction[1]][:matches_labels] != restriction[3]
      @variables[restriction[1]][:eq].push restriction[2].sort
      restriction
    when :neq_u
      @variables[restriction[1]] ||= {:multi => true, :ordered => false, :eq => [], :matches_labels => restriction[3], :computations => []}
      @variables[restriction[1]][:ordered] = false if @variables[restriction[1]][:ordered].nil?
      @variables[restriction[1]][:matches_labels] = restriction[3] if @variables[restriction[1]][:matches_labels].nil?
      raise "Can't have the same variable match single nodes and multiple nodes" unless @variables[restriction[1]][:multi]
      raise "Can't have the same variable match multiple ordered nodes and multiple unordered nodes" if @variables[restriction[1]][:ordered]
      raise "Can't have the same variable match labels and not match labels" if @variables[restriction[1]][:matches_labels] != restriction[3]
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
        simplify [:neq, restriction[1][1], restriction[1][2], restriction[1][3]]
      elsif restriction[1][0] == :neq
        simplify [:eq, restriction[1][1], restriction[1][2], restriction[1][3]]
      elsif restriction[1][0] == :eq_o
        simplify [:neq_o, restriction[1][1], restriction[1][2], restriction[1][3]]
      elsif restriction[1][0] == :neq_o
        simplify [:eq_o, restriction[1][1], restriction[1][2], restriction[1][3]]
      elsif restriction[1][0] == :eq_u
        simplify [:neq_u, restriction[1][1], restriction[1][2], restriction[1][3]]
      elsif restriction[1][0] == :neq_u
        simplify [:eq_u, restriction[1][1], restriction[1][2], restriction[1][3]]
      elsif restriction[1][0] == :not
        simplify restriction[1][1]
      elsif restriction[1][0] == :and
        simplify [:or, [:not, restriction[1][1]], [:not, restriction[1][2]]]
      elsif restriction[1][0] == :or
        simplify [:and, [:not, restriction[1][1]], [:not, restriction[1][2]]]
      end
    when :add, :subtract, :multiply, :divide
      restriction[1...-1].each do |part|
        if part.is_a?(Array) && part[0] == :var
          @variables[part[1]] ||= {:eq => [], :computations => []}
          raise "Can't have the same variable match single nodes and multiple nodes" if @variables[part[1]][:multi]
          @variables[part[1]][:computations].push restriction
        elsif part.is_a?(Array) && part[0] == :multivar
          @variables[part[1]] ||= {:multi => true, :eq => [], :computations => []}
          raise "Can't have the same variable match single nodes and multiple nodes" unless @variables[part[1]][:multi]
          @variables[part[1]][:computations].push restriction
        elsif part.is_a?(Fixnum) || part.is_a?(Float)
        else
          raise "Unrecognized computation part: #{part.inspect}"
        end
      end
      restriction
    else
      raise "Don't know how to simplify #{restriction.inspect}"
    end
  end

  def check restriction
    return restriction if [true, false].include? restriction
    case restriction[0]
    when :eq
      @variables[restriction[1]][:eq].all? {|node| restriction[3] ? restriction[2] == node : restriction[2].equals_except_label?(node)} && @variables[restriction[1]][:computations].all? {|computation| check_computation computation}
    when :neq
      raise 'Can not check if a node is not equal to a variable that does not have a matching node' if @variables[restriction[1]][:eq].empty? && @variables[restriction[1]][:computations].empty?
      @variables[restriction[1]][:eq].all? {|node| restriction[3] ? restriction[2] != node : !restriction[2].equals_except_label?(node)} && @variables[restriction[1]][:computations].none? {|computation| check_computation computation}
    when :eq_o, :eq_u
      @variables[restriction[1]][:eq].all? {|nodes| nodes.length == restriction[2].length && nodes.zip(restriction[2]).all? {|node, expected| restriction[3] ? expected == node : expected.equals_except_label?(node)}} && @variables[restriction[1]][:computations].all? {|computation| check_computation computation}
    when :neq_o, :neq_u
      raise 'Can not check if nodes are not equal to a variable that does not have matching nodes' if @variables[restriction[1]][:eq].empty? && @variables[restriction[1]][:computations].empty?
      @variables[restriction[1]][:eq].all? {|nodes| nodes.length != restriction[2].length || nodes.zip(restriction[2]).any? {|node, expected| restriction[3] ? expected != node : !expected.equals_except_label?(node)}} && @variables[restriction[1]][:computations].none? {|computation| check_computation computation}
    when :and
      check(restriction[1]) && check(restriction[2])
    when :or
      check(restriction[1]) || check(restriction[2])
    when :add, :subtract, :multiply, :divide
      check_computation restriction
    else
      raise "Don't know how to check #{restriction.inspect}"
    end
  end

  def check_computation computation
    supplied = computation[1..-1].select {|part| part.is_a?(Array) && part[0] == :var && (!@variables.has_key?(part[1]) || @variables[part[1]][:eq].empty?)}
    return false if supplied.length > 1 # TODO: shouldn't this be an error?
    supplied = supplied.first

    case computation[0]
    when :add
      if supplied.nil?
        computation[1...-1].inject(0) do |sum, part|
          sum + (part.is_a?(Array) ? (part[0] == :multivar ? @variables[part[1]][:eq].sample.inject(0) {|subsum, node| subsum + node.value} : @variables[part[1]][:eq].sample.value) : part)
        end == (computation.last.is_a?(Array) ? @variables[computation.last[1]][:eq].sample.value : computation.last)
      elsif supplied == computation.last
        value = computation[1...-1].inject(0) do |sum, part|
          sum + (part.is_a?(Array) ? (part[0] == :multivar ? @variables[part[1]][:eq].sample.inject(0) {|subsum, node| subsum + node.value} : @variables[part[1]][:eq].sample.value) : part)
        end
        (@variables[supplied[1]] ||= {:eq => []})[:value] ||= value
        @variables[supplied[1]][:value] == value
      else
        value = (computation.last.is_a?(Array) ? @variables[computation.last[1]][:eq].sample.value : computation.last) - computation[1...-1].inject(0) do |sum, part|
          next sum if part == supplied
          sum + (part.is_a?(Array) ? (part[0] == :multivar ? @variables[part[1]][:eq].sample.inject(0) {|subsum, node| subsum + node.value} : @variables[part[1]][:eq].sample.value) : part)
        end
        (@variables[supplied[1]] ||= {:eq => []})[:value] ||= value
        @variables[supplied[1]][:value] == value
      end
    when :subtract
      if supplied.nil?
        (computation[1].is_a?(Array) ? @variables[computation[1][1]][:eq].sample.value : computation[1]) - computation[2...-1].inject(0) do |sum, part|
          sum + (part.is_a?(Array) ? (part[0] == :multivar ? @variables[part[1]][:eq].sample.inject(0) {|subsum, node| subsum + node.value} : @variables[part[1]][:eq].sample.value) : part)
        end == (computation.last.is_a?(Array) ? @variables[computation.last[1]][:eq].sample.value : computation.last)
      elsif supplied == computation[1]
        value = computation[2...-1].inject(0) do |sum, part|
          sum + (part.is_a?(Array) ? (part[0] == :multivar ? @variables[part[1]][:eq].sample.inject(0) {|subsum, node| subsum + node.value} : @variables[part[1]][:eq].sample.value) : part)
        end + (computation.last.is_a?(Array) ? @variables[computation.last[1]][:eq].sample.value : computation.last)
        (@variables[supplied[1]] ||= {:eq => []})[:value] ||= value
        @variables[supplied[1]][:value] == value
      elsif supplied == computation.last
        value = (computation[1].is_a?(Array) ? @variables[computation[1][1]][:eq].sample.value : computation[1]) - computation[2...-1].inject(0) do |sum, part|
          sum + (part.is_a?(Array) ? (part[0] == :multivar ? @variables[part[1]][:eq].sample.inject(0) {|subsum, node| subsum + node.value} : @variables[part[1]][:eq].sample.value) : part)
        end
        (@variables[supplied[1]] ||= {:eq => []})[:value] ||= value
        @variables[supplied[1]][:value] == value
      else
        value = (computation[1].is_a?(Array) ? @variables[computation[1][1]][:eq].sample.value : computation[1]) - computation[2...-1].inject(0) do |sum, part|
          next sum if part == supplied
          sum + (part.is_a?(Array) ? (part[0] == :multivar ? @variables[part[1]][:eq].sample.inject(0) {|subsum, node| subsum + node.value} : @variables[part[1]][:eq].sample.value) : part)
        end - (computation.last.is_a?(Array) ? @variables[computation.last[1]][:eq].sample.value : computation.last)
        (@variables[supplied[1]] ||= {:eq => []})[:value] ||= value
        @variables[supplied[1]][:value] == value
      end
    when :multiply
      if supplied.nil?
        computation[1...-1].inject(1) do |product, part|
          product * (part.is_a?(Array) ? (part[0] == :multivar ? @variables[part[1]][:eq].sample.inject(1) {|subproduct, node| subproduct * node.value} : @variables[part[1]][:eq].sample.value) : part)
        end == (computation.last.is_a?(Array) ? @variables[computation.last[1]][:eq].sample.value : computation.last)
      elsif supplied == computation.last
        value = computation[1...-1].inject(1) do |product, part|
          product * (part.is_a?(Array) ? (part[0] == :multivar ? @variables[part[1]][:eq].sample.inject(1) {|subproduct, node| subproduct * node.value} : @variables[part[1]][:eq].sample.value) : part)
        end
        (@variables[supplied[1]] ||= {:eq => []})[:value] ||= value
        @variables[supplied[1]][:value] == value
      else
        value = (computation.last.is_a?(Array) ? @variables[computation.last[1]][:eq].sample.value : computation.last) / computation[1...-1].inject(1) do |product, part|
          next product if part == supplied
          product * (part.is_a?(Array) ? (part[0] == :multivar ? @variables[part[1]][:eq].sample.inject(1) {|subproduct, node| subproduct + node.value} : @variables[part[1]][:eq].sample.value) : part)
        end
        (@variables[supplied[1]] ||= {:eq => []})[:value] ||= value
        @variables[supplied[1]][:value] == value
      end
    when :divide
      if supplied.nil?
        (computation[1].is_a?(Array) ? @variables[computation[1][1]][:eq].sample.value : computation[1]) / (computation[2].is_a?(Array) ? @variables[computation[2][1]][:eq].sample.value : computation[2]) == (computation[3].is_a?(Array) ? @variables[computation[3][1]][:eq].sample.value : computation[3])
      elsif supplied == computation[1]
        value = (computation[2].is_a?(Array) ? @variables[computation[2][1]][:eq].sample.value : computation[2]) * (computation[3].is_a?(Array) ? @variables[computation[3][1]][:eq].sample.value : computation[3])
        (@variables[supplied[1]] ||= {:eq => []})[:value] ||= value
        @variables[supplied[1]][:value] == value
      elsif supplied == computation[2]
        value = (computation[1].is_a?(Array) ? @variables[computation[1][1]][:eq].sample.value : computation[1]) / (computation[3].is_a?(Array) ? @variables[computation[3][1]][:eq].sample.value : computation[3])
        (@variables[supplied[1]] ||= {:eq => []})[:value] ||= value
        @variables[supplied[1]][:value] == value
      elsif supplied == computation[3]
        value = (computation[1].is_a?(Array) ? @variables[computation[1][1]][:eq].sample.value : computation[1]) / (computation[2].is_a?(Array) ? @variables[computation[2][1]][:eq].sample.value : computation[2])
        (@variables[supplied[1]] ||= {:eq => []})[:value] ||= value
        @variables[supplied[1]][:value] == value
      else
        raise
      end
    else
      raise "Don't know how to compute #{computation.inspect}"
    end
  end
end
