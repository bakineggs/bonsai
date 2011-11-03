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
            if (child->type == #{condition.node_type == :root ? "root_node_type" : "node_type_for(\"#{condition.node_type}\")"}) {
          EOS

          if condition.child_rule
            child_rules_match += rule_matches condition.child_rule
            rule_matches += <<-EOS
              Match* child_match = rule_#{condition.child_rule.object_id}_matches(child);
              if (child_match) {
                release_match_memory(child_match);
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
          if (false) // TODO: if there are no unmatched nodes
            return release_match_memory(first_match);
        EOS
      end

      rule_matches += <<-EOS
          return first_match;
        }
      EOS

      "#{child_rules_match}\n#{rule_matches}"
    end

    def rule_matches_out_of_order rule
      child_rules_match = ""
      rule_matches = <<-EOS
        Match* rule_#{rule.object_id}_matches_out_of_order(Node* node) {
      EOS

      unless rule.conditions_can_match_ordered_nodes_out_of_order?
        rule_matches += <<-EOS
          if (node->children_are_ordered)
            return NULL;
        EOS
      end

      rule_matches += <<-EOS
          if (false) // TODO: if any preventing rule matches one of the node's children
            return NULL;

          if (false) { // TODO: if there is a one-to-one mapping of singly-matched conditions to node's children
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
            return NULL; // TODO: return the match
          }
      EOS

      rule_matches += <<-EOS
          return NULL;
        }
      EOS

      "#{child_rules_match}\n#{rule_matches}"
    end

    def transform_rule rule
      <<-EOS
        bool transform_rule_#{rule.object_id}(Match* match) {
          return false;
        }
      EOS
    end
end
