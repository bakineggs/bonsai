require File.dirname(__FILE__) + '/parser'

class Compiler
  def compile program
    rules = Parser.new.parse_rules program

    <<-EOS
      #include <stdlib.h>
      #include <stdio.h>
      #include <string.h>

      #{File.read File.dirname(__FILE__) + '/../types.h'}

      #{File.read File.dirname(__FILE__) + '/runtime.c'}

      #{apply_rules rules}
    EOS
  end

  private
    def apply_rules rules
      apply_rules = rules.map {|rule| "#{rule_matches rule}\n#{transform_rule rule}"}.join "\n"

      apply_rules += <<-EOS
        bool apply_rules(Node* node) {
          Match* match;
      EOS

      apply_rules += rules.map do |rule|
        <<-EOS
          if ((match = rule_#{rule.object_id}_matches(node)) && transform_rule_#{rule.object_id}(match))
            return true;
        EOS
      end.join ' else '

      apply_rules + <<-EOS
          return false;
        }
      EOS
    end

    def rule_matches rule
      child_rules_match = ""
      rule_matches = <<-EOS
        Match* rule_#{rule.object_id}_matches(Node* node) {
          Match* match = NULL;
      EOS

      if rule.conditions_can_match_in_order?
        child_rules_match += rule_matches_in_order rule
        rule_matches += <<-EOS
          if (match = rule_#{rule.object_id}_matches_in_order(node))
            return match;
        EOS
      end

      if rule.conditions_can_match_out_of_order?
        child_rules_match += rule_matches_out_of_order rule
        rule_matches += <<-EOS
          if (match = rule_#{rule.object_id}_matches_out_of_order(node))
            return match;
        EOS
      end

      rule_matches += <<-EOS
          return NULL;
        }
      EOS

      "#{child_rules_match}\n#{rule_matches}"
    end

    def rule_matches_in_order rule
      child_rules_match = ""
      rule_matches = <<-EOS
        Match* rule_#{rule.object_id}_matches_in_order(Node* node) {
          if (!node->children_are_ordered)
            return NULL;

          Match* first_match = NULL;
          Match* current_match = NULL;
          Node* child = node->children;
      EOS

      rule.conditions.each do |condition|
        if condition.creates_node?
          rule_matches += <<-EOS
            Match* creating_match = (Match*) malloc(sizeof(Match));
            creating_match->next = NULL;
            creating_match->child = NULL;
            creating_match->node = child;
            if (current_match) {
              current_match->next = creating_match;
              current_match = creating_match;
            } else
              first_match = current_match = creating_match;
          EOS
        elsif condition.prevents_match?
          rule_matches += <<-EOS
            if (child->type == #{condition.node_type == :root ? "ROOT_NODE_TYPE" : "node_type_for(\"#{condition.node_type}\")"}) { // TODO: global for node type
          EOS

          if condition.child_rule
            child_rules_match += rule_matches condition.child_rule
            rule_matches += <<-EOS
              Match* preventing_match = rule_#{condition.child_rule.object_id}_matches(child);
              if (preventing_match) {
                release_match_memory(preventing_match);
                return release_match_memory(first_match);
              }
            EOS
          else
            rule_matches += <<-EOS
              return release_match_memory(first_match);
            EOS
          end

          rule_matches += <<-EOS
            }
          EOS
        elsif condition.matches_multiple_nodes?
          # TODO
        else
          # TODO
        end
      end

      if rule.must_match_all_nodes?
        rule_matches += <<-EOS
          if (false) // TODO: if there are any unmatched nodes
            return release_match_memory(first_match);
        EOS
      end

      rule_matches += <<-EOS
          return first_match ? first_match : EMPTY_MATCH;
        }
      EOS

      "#{child_rules_match}\n#{rule_matches}"
    end

    def rule_matches_out_of_order rule
      singly_matched_conditions = rule.conditions.select &:must_match_a_node?

      rule_matches = <<-EOS
        Match* rule_#{rule.object_id}_matches_out_of_order(Node* node) {
          #{"if (node->children_are_ordered) return NULL;" unless rule.conditions_can_match_ordered_nodes_out_of_order?}

          if (false) // TODO: if any preventing rule matches one of the node's children
            return NULL;

          Match* match = EMPTY_MATCH;
          #{"match = map_conditions_starting_from_#{singly_matched_conditions.first.object_id}(node, NULL);" unless singly_matched_conditions.empty?}
          if (match) {
            // TODO: greedily map multiply-matched conditions to node's unmatched children
      EOS

      if rule.must_match_all_nodes?
        rule_matches += <<-EOS
            if (false) // TODO: if there are any unmatched nodes
              return NULL;
        EOS
      end

      rule_matches += <<-EOS
            // TODO: add creating conditions to the match
            return match; // TODO: return the match
          }
      EOS

      rule_matches += <<-EOS
          return NULL;
        }
      EOS

      "#{one_to_one_mapping singly_matched_conditions}\n#{rule_matches}"
    end

    def one_to_one_mapping conditions
      return "" unless condition = conditions.first
      other_conditions = conditions[1..-1]

      mapping = <<-EOS
        Match* map_conditions_starting_from_#{condition.object_id}(Node* node, Match* matched) {
          Node* child = node->children;

          while (child) {
            if (child->type == node_type_for("#{condition.node_type}") && !already_matched(child, matched)) { // TODO: create a global for each node type in a condition instead of looking it up each time
              Match* match = (Match*) malloc(sizeof(Match));
              if (match->child = rule_#{condition.child_rule.object_id}_matches(child)) {
                match->alternate = NULL;
                match->next = NULL;
                #{"if (match->next = map_conditions_starting_from_#{other_conditions.first.object_id}(node, match))" unless other_conditions.empty?}
                return match;
              }
              release_match_memory(match);
            }
            child = child->next_sibling;
          }

          return NULL;
        }
      EOS

      "#{rule_matches condition.child_rule}\n#{one_to_one_mapping other_conditions}\n#{mapping}"
    end

    def transform_rule rule
      <<-EOS
        bool transform_rule_#{rule.object_id}(Match* match) {
          return false;
        }
      EOS
    end
end
