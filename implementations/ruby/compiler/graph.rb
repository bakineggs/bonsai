require 'set'
require_relative 'rule'

class Graph
  def initialize rules
    @edges = {}
    @path_diffs = {}
    @path_diffs_reversed = {}

    rules = rules.to_set

    empty_tree = nil # TODO: "^:=" matcher
    empty_tree_matching_rules = rules.select {|rule| rule.definitely_matches? empty_tree}.to_set

    explored = {}
    forwarded = {}
    @queue = empty_tree_matching_rules.map do |rule|
      [empty_tree_matching_rules, Set.new, empty_tree, rule]
    end

    possibly_enabling = Hash[rules.map do |rule|
      [rule, rules.select do |other_rule|
        rule.could_enable? other_rule
      end.to_set]
    end]

    until @queue.empty?
      definitely_matching, possibly_matching, matcher, rule = @queue.shift
      matcher = forwarded[[definitely_matching, possibly_matching, matcher]] while forwarded[[definitely_matching, possibly_matching, matcher]]
      next if explored[[definitely_matching, possibly_matching, matcher, rule]]

      next_definitely_matching_base = definitely_matching - possibly_matching.select {|next_rule| rule.could_prevent? next_rule}
      next_possibly_matching_base = possibly_matching + definitely_matching + possibly_enabling[rule] - next_definitely_matching_base

      rule.transform(matcher).each do |next_matcher|
        next_definitely_matching = next_definitely_matching_base + next_possibly_matching_base.select {|next_rule| next_rule.definitely_matches? next_matcher}
        next_possibly_matching = next_possibly_matching_base - (next_definitely_matching - next_definitely_matching_base)
        next_possibly_matching -= next_possibly_matching.select {|next_rule| next_rule.definitely_doesnt_match? next_matcher}
        next_matcher = forwarded[[next_definitely_matching, next_possibly_matching, next_matcher]] while forwarded[[next_definitely_matching, next_possibly_matching, next_matcher]]

        # TODO: check if any existing matchers on the state could be merged with next_matcher and forwarded (which could make the later cycle stuff easier)

        create_edge [definitely_matching, possibly_matching, matcher], [next_definitely_matching, next_possibly_matching, next_matcher]
      end

      explored[[definitely_matching, possibly_matching, matcher, rule]] = true
    end
  end

  private

  def create_edge source, destination
    @edges[source.first 2] ||= {}
    @edges[source.first 2][source.last] ||= {}
    @edges[source.first 2][source.last][destination.first 2] ||= {}
    return false if @edges[source.first 2][source.last][destination.first 2].has_key? destination.last

    diff = destination.last.diff source.last
    @edges[source.first 2][source.last][destination.first 2][destination.last] = diff

    (destination[0] + destination[1]).each do |rule|
      @queue.push destination + [rule]
    end

    @path_diffs[source] ||= {}
    @path_diffs[source][destination] ||= Set.new
    return true if @path_diffs[source][destination].include? diff

    @path_diffs[source][destination].add diff
    @path_diffs_reversed[destination] ||= {}
    @path_diffs_reversed[destination][source] ||= Set.new
    @path_diffs_reversed[destination][source].add diff

    @path_diffs_reversed[source].keys.each do |reaches_source|
      @path_diffs[destination].keys.each do |destination_reaches|
        combined_diff = @path_diffs[reaches_source][source] + diff + @path_diffs[destination][destination_reaches]
        @path_diffs[reaches_source][destination_reaches] ||= Set.new
        @path_diffs[reaches_source][destination_reaches].add combined_diff
        @path_diffs_reversed[destination_reaches][reaches_source] ||= Set.new
        @path_diffs_reversed[destination_reaches][reaches_source].add combined_diff
      end
    end

    (@edges[destination.first 2] || {}).keys.each do |destination_sibling|
      next unless @path_diffs[destination_sibling] && @path_diffs[destination_sibling][source]
      @path_diffs[destination_sibling][source].each do |cycle_diff|
        cycle_diff += diff
        last_node = destination
        cycle_diff.ranges(destination).each do |low, high, definitely_matching, possibly_matching, matcher|
          if high == Float::INFINITY
            create_edge last_node, [definitely_matching, possibly_matching, matcher]
            last_node = [definitely_matching, possibly_matching, matcher]
          else
            (low..high).each do |multiplier|
              next if multiplier == 0
              create_edge last_node, [definitely_matching, possibly_matching, matcher]
              last_node = [definitely_matching, possibly_matching, matcher]
              matcher += cycle_diff unless multiplier == high
            end
          end
        end
      end
    end

    true
  end
end
