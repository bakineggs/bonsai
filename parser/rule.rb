class Rule
  attr_reader :conditions, :definition

  def initialize options = {}
    @conditions_are_ordered = options[:conditions_are_ordered]
    @must_match_all_nodes = options[:must_match_all_nodes]
    @conditions = options[:conditions]
    @definition = options[:definition]
  end

  def conditions_are_ordered?
    !!@conditions_are_ordered
  end

  def must_match_all_nodes?
    !!@must_match_all_nodes
  end
end
