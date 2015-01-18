class Rule
  attr_reader :conditions, :definition

  def initialize options = {}
    @conditions_are_ordered = !!options[:conditions_are_ordered]
    @must_match_all_nodes = !!options[:must_match_all_nodes]
    @conditions = options[:conditions]
    @definition = options[:definition]

    raise Error.new 'A rule must have an Array of Condition conditions' unless @conditions.is_a?(Array) && @conditions.all? {|condition| condition.is_a? Condition}
    raise Error.new 'A rule must have an Array of String definition' unless @definition.is_a?(Array) && @definition.all? {|line| line.is_a? String}
  end

  def conditions_are_ordered?
    @conditions_are_ordered
  end

  def must_match_all_nodes?
    @must_match_all_nodes
  end

  class Error < StandardError; end
end
