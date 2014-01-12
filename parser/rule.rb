class Rule
  attr_reader :conditions, :code_segment, :definition

  def initialize options = {}
    @top_level = options[:top_level]
    @conditions_are_ordered = options[:conditions_are_ordered]
    @must_match_all_nodes = options[:must_match_all_nodes]
    @conditions = options[:conditions]
    @code_segment = options[:code_segment]
    @definition = options[:definition]
  end

  def top_level?
    !!@top_level
  end

  def conditions_are_ordered?
    !!@conditions_are_ordered
  end

  def must_match_all_nodes?
    !!@must_match_all_nodes
  end

  def conditions_can_match_in_order?
    conditions_are_ordered? || @top_level
  end

  def conditions_can_match_out_of_order?
    !conditions_are_ordered? || @top_level
  end

  def conditions_can_match_ordered_nodes_out_of_order?
    !conditions_are_ordered? && !@top_level
  end

  def variables
    return @variables if @variables
    @variables = {} # name => conditions

    conditions.each do |condition|
      condition.child_rule.variables.each do |name, conditions|
        (@variables[name] ||= []).push *conditions
      end

      if condition.node_must_match_variable_value? || condition.has_value_set_by_variable?
        (@variables[condition.variable] ||= []).push condition
      end
    end

    @variables
  end
end
