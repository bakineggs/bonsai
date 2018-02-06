require 'set'
require_relative 'rule'
require_relative 'rule_application_graph'

class PotentialStateGraph
  def initialize rules
    rule_application_graph = RuleApplicationGraph.new rules

    #@nodes = {[rules.select {|rule| rule.definitely_matches? root}.to_set, Set.new, Set.new] => root} # TODO: use matcher for root
    #@edges = {@nodes.keys.first => Set.new}
    @nodes = {}
    @edges = {}

    modified_last_time_step = nil
    modified_this_time_step = @nodes.keys
    time_step = 0
    until modified_this_time_step.empty?
      time_step += 1
      modified_last_time_step = modified_this_time_step
      modified_this_time_step = Set.new
      need_to_merge = {}
      new_edges = Set.new

      modified_last_time_step.each do |node_identifier|
        (node_identifier[0] + node_identifier[1]).each do |rule|
          rule.transform(@nodes[node_identifier]).each do |state|
            definitely_matches = rule_application_graph.definitely_matching time_step
            raise unless definitely_matches.all? {|definitely_matching_rule| definitely_matching_rule.definitely_matches? state}
            definitely_matches += rule_application_graph.possibly_matching(time_step).select {|possibly_matching_rule| possibly_matching_rule.definitely_matches? state}
            possibly_matches = rule_application_graph.possibly_matching(time_step) - definitely_matches
            possibly_matches -= possibly_matches.select {|possibly_matching_rule| possibly_matching_rule.definitely_does_not_match? state}
            remaining = rule_application_graph.possibly_matching(time_step) - definitely_matches - possibly_matches
            resultant_node_identifier = [definitely_matches, possibly_matches, remaining]
            if @nodes[resultant_node_identifier]
              need_to_merge[resultant_node_identifier] ||= Set.new
              need_to_merge[resultant_node_identifier].add state
            else
              @nodes[resultant_node_identifier] = state
              @edges[resultant_node_identifier] = {}
              modified_this_time_step.add resultant_node_identifier
            end
            if @edges[node_identifier][resultant_node_identifier]
              @edges[node_identifier][resultant_node_identifier].add rule
            else
              @edges[node_identifier][resultant_node_identifier] = [rule].to_set
              new_edges.add [node_identifier, resultant_node_identifier]
            end
          end
        end
      end

      need_to_merge.each do |node_identifier, states|
        @nodes[node_identifier] = states.inject(@nodes[node_identifier]) {|state, state_to_merge| state + state_to_merge}
        modified_this_time_step.add node_identifier
      end

      new_edges.each do |source_identifier, destination_identifier|
        # TODO: for each new nonstationary cycle created by this edge, modify the state of each node in the cycle to accomodate any number of iterations of the cycle
      end

      # TODO: for each node whose state was modified by a nonstationary cycle, find any split points that could change the identifier and create new nodes & edges
    end
  end
end
