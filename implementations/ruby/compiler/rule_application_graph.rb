require 'set'
require_relative 'rule'

class RuleApplicationGraph
  def initialize rules
    rules = rules.to_set
    #@nodes = [[rules.select {|rule| rule.definitely_matches? root}.to_set, Set.new]] # TODO: use matcher for root
    @nodes = [[Set.new, rules.to_set]]
    indexes = {@nodes.first => 0}

    loop do
      previous_rules = @nodes.last[0] + @nodes.last[1]

      definitely_matches = @nodes.last[0] - @nodes.last[0].select {|rule| previous_rules.any? {|previous_rule| previous_rule.definitely_disables?(rule) || previous_rule.possibly_disables?(rule)}}
      definitely_matches += (rules - definitely_matches).select {|rule| previous_rules.all? {|previous_rule| previous_rule.definitely_enables? rule}}

      possibly_matches = previous_rules - previous_rules.select {|rule| previous_rules.all? {|previous_rule| previous_rule.definitely_disables? rule}}
      possibly_matches += (rules - possibly_matches).select {|rule| previous_rules.any? {|previous_rule| previous_rule.possibly_enables? rule}}
      possibly_matches -= definitely_matches

      break if @repeat = indexes[[definitely_matches, possibly_matches]]
      @nodes.push [definitely_matches, possibly_matches]
      break if definitely_matches.empty? && possibly_matches.empty?
      indexes[@nodes.last] = @nodes.length - 1
    end
  end

  def definitely_matching time_step
    raise if @repeat.nil? && time_step >= @nodes.length
    time_step = @repeat + (time_step - @repeat) % (@nodes.length - @repeat) if @repeat && time_step >= @nodes.length
    @nodes[time_step][0]
  end

  def possibly_matching time_step
    raise if @repeat.nil? && time_step >= @nodes.length
    time_step = @repeat + (time_step - @repeat) % (@nodes.length - @repeat) if @repeat && time_step >= @nodes.length
    @nodes[time_step][1]
  end
end
