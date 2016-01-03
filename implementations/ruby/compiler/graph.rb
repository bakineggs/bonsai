require 'set'
require_relative 'rule'
require_relative 'state'

class Graph
  def initialize rules
    rules = rules.to_set
    @starting_state = State.new
    @edges = {}
    @expanded = {}

    @preventing  = Hash[rules.map do |rule|
      [rule, rules.select do |other_rule|
        rule.prevents? other_rule
      end.to_set]
    end]

    @affecting  = Hash[rules.map do |rule|
      [rule, (rules - @preventing[rule]).select do |other_rule|
        rule.affects? other_rule
      end.to_set]
    end]

    expand @starting_state, rules.select {|rule| !@starting_state.apply(rule).empty?}.to_set
  end

  private

  def expand state, rules
    return if (@expanded[state] ||= Set.new).include? rules
    @expanded[state].add rules

    @edges[state] ||= {}
    rules.each do |rule|
      state.apply(rule).each do |result|
        (@edges[state][result] ||= Set.new).add rule
        expand result, rules + @affecting[rule] - @preventing[rule]
      end
    end
  end
end
