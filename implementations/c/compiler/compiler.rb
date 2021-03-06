require_relative 'parser'

class Compiler
  def compile program
    program = Parser.new.parse_program program

    <<-EOS
      #include <stdlib.h>
      #include <stdio.h>
      #include <string.h>

      #{File.read File.dirname(__FILE__) + '/../types.h'}

      #{setup_node_types program[:rules]}

      #{File.read File.dirname(__FILE__) + '/../node_builder.c'}
      #{File.read File.dirname(__FILE__) + '/../print.c'}
      #{File.read File.dirname(__FILE__) + '/runtime.c'}

      #{program[:header]}

      #{apply_rules program[:rules]}
    EOS
  end

  private
    def setup_node_types rules
      types = rules.map{|rule| node_types rule}.flatten.uniq
      length = types.length + 3
      capacity = ((length - 1) / 64 + 1) * 64

      declarations = <<-EOS
        char* ROOT_NODE_TYPE = "^";
        char* ROOT_PARENT_NODE_TYPE = "^^";
        char* ANY_NODE_TYPE = "*";
        char** node_types;
        int node_types_length = #{length};
        int node_types_capacity = #{capacity};
      EOS

      setup_node_types = <<-EOS
        void setup_node_types() {
          node_types = (char**) malloc(#{capacity} * sizeof(char*));
          node_types[0] = ROOT_NODE_TYPE;
          node_types[1] = ROOT_PARENT_NODE_TYPE;
          node_types[2] = ANY_NODE_TYPE;
      EOS

      types.each_with_index do |type, index|
        declarations += "char* #{type_var_for type} = \"#{type}\";\n"
        setup_node_types += "node_types[#{index + 3}] = #{type_var_for type};\n"
      end

      <<-EOS
        #{declarations}
        #{setup_node_types}
        }
      EOS
    end

    def type_var_for type
      return "#{type.to_s.upcase}_NODE_TYPE" if type.is_a? Symbol
      "node_type_for_#{type.gsub ' ', '_'}"
    end

    def node_types rule
      rule.conditions.map do |condition|
        types = node_types condition.child_rule
        types.push condition.node_type unless condition.node_type.is_a? Symbol
        types
      end.flatten.uniq
    end

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
      child_rules_match = rule.conditions.map {|condition| rule_matches condition.child_rule}.join "\n"

      rule_matches = rule_definition_comment rule

      rule_matches += <<-EOS
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
      rule_matches = <<-EOS
        Match* rule_#{rule.object_id}_matches_in_order(Node* node) {
          if (!node->children_are_ordered)
            return NULL;

          Match* first_match = NULL;
          Match* current_match = NULL;
          Match* new_match;
          Match* child_match;
          Node* previous_child = NULL;
          Node* next_child = node->children;
      EOS

      next_child = <<-EOS
        previous_child = next_child ? next_child : previous_child;
        next_child = next_child ? next_child->next_sibling : next_child;
      EOS

      rule.conditions.each do |condition|
        if condition.creates_node?
          rule_matches += <<-EOS
            new_match = (Match*) malloc(sizeof(Match));
            new_match->condition_id = #{condition.object_id};
            new_match->next_match = NULL;
            new_match->child_match = NULL;
            new_match->matched_node = next_child;
            new_match->parent_of_matched_node = node;
            new_match->previous_sibling_of_matched_node = previous_child;
            if (current_match) {
              current_match->next_match = new_match;
              current_match = new_match;
            } else
              first_match = current_match = new_match;
          EOS
        elsif condition.prevents_match?
          rule_matches += <<-EOS
            if (next_child && next_child->type == #{type_var_for condition.node_type}) {
              Match* preventing_match = rule_#{condition.child_rule.object_id}_matches(next_child);
              if (preventing_match) {
                release_match_memory(preventing_match);
                return release_match_memory(first_match);
              }
            }
            #{next_child}
          EOS
        elsif condition.matches_multiple_nodes?
          rule_matches += <<-EOS
            // TODO
          EOS
        else
          rule_matches += <<-EOS
            if (next_child && next_child->type == #{type_var_for condition.node_type}) {
              child_match = rule_#{condition.child_rule.object_id}_matches(next_child);
              if (!child_match)
                return release_match_memory(first_match);

              new_match = (Match*) malloc(sizeof(Match));
              new_match->condition_id = #{condition.object_id};
              new_match->next_match = NULL;
              new_match->child_match = child_match;
              new_match->matched_node = next_child;
              new_match->parent_of_matched_node = node;
              new_match->previous_sibling_of_matched_node = previous_child;

              #{next_child}
            } else
              return release_match_memory(first_match);
          EOS
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

      rule_matches
    end

    def rule_matches_out_of_order rule
      preventing_conditions = rule.conditions.select &:prevents_match?
      singly_matched_conditions = rule.conditions.select &:must_match_a_node?

      rule_matches = <<-EOS
        Match* rule_#{rule.object_id}_matches_out_of_order(Node* node) {
          #{"if (node->children_are_ordered) return NULL;" unless rule.conditions_can_match_ordered_nodes_out_of_order?}

          Node* preventing_child;
      EOS

      preventing_conditions.each do |condition|
        rule_matches += <<-EOS
          preventing_child = node->children;
          while (preventing_child) {
            if (preventing_child->type == #{type_var_for condition.node_type}) {
              Match* preventing_match = rule_#{condition.child_rule.object_id}_matches(preventing_child);
              if (preventing_match)
                return release_match_memory(preventing_match);
            }
            preventing_child = preventing_child->next_sibling;
          }
        EOS
      end

      rule_matches += <<-EOS
          Match* match = EMPTY_MATCH;
          Match* creating_match;
          #{"match = map_conditions_starting_from_#{singly_matched_conditions.first.object_id}(node, NULL);" unless singly_matched_conditions.empty?}
          if (match) {
            // TODO: greedily map multiply-matched conditions to node's unmatched children
      EOS

      if rule.must_match_all_nodes?
        rule_matches += <<-EOS
            if (false) // TODO: if there are any unmatched nodes
              return release_match_memory(match);
        EOS
      end

      rule.conditions.select(&:creates_node?).each do |condition|
        rule_matches += <<-EOS
            creating_match = (Match*) malloc(sizeof(Match));
            creating_match->condition_id = #{condition.object_id};
            creating_match->next_match = NULL;
            creating_match->child_match = NULL;
            creating_match->matched_node = node->children;
            creating_match->parent_of_matched_node = node;
            creating_match->previous_sibling_of_matched_node = NULL;

            if (match != EMPTY_MATCH)
              creating_match->next_match = match;
            match = creating_match;
        EOS
      end

      rule_matches += <<-EOS
            return match;
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
            if (child->type == #{type_var_for condition.node_type} && !already_matched(child, matched)) {
              Match* match = (Match*) malloc(sizeof(Match));
              if (match->child_match = rule_#{condition.child_rule.object_id}_matches(child)) {
                match->next_match = NULL;
                #{"if (match->next_match = map_conditions_starting_from_#{other_conditions.first.object_id}(node, match)) {" unless other_conditions.empty?}
                  #{"match->child_match = release_match_memory(match->child_match);" if condition.removes_node?}
                  match->condition_id = #{condition.object_id};
                  match->matched_node = child;
                  match->parent_of_matched_node = node;
                  match->previous_sibling_of_matched_node = child->previous_sibling;
                  return match;
                #{"}" unless other_conditions.empty?}
              }
              release_match_memory(match);
            }
            child = child->next_sibling;
          }

          return NULL;
        }
      EOS

      "#{one_to_one_mapping other_conditions}\n#{mapping}"
    end

    def transform_rule rule
      transform_child_rules = ""

      transform_rule = rule_definition_comment rule

      transform_rule += <<-EOS
        bool transform_rule_#{rule.object_id}(Match* match) {
          bool transformed = false;

          #{rule.variables.keys.map{|v| "Node* variable_#{v};"}.join("\n")}

          while (match && match != EMPTY_MATCH) {
      EOS

      rule.conditions.each do |condition|
        transform_child_rules += transform_rule condition.child_rule
        transform_child_rules += create_node condition if condition.creates_node?
        transform_rule += <<-EOS
            if (match->condition_id == #{condition.object_id}) {
              #{"create_node_#{condition.object_id}(match); transformed = true;" if condition.creates_node?}
              if (transform_rule_#{condition.child_rule.object_id}(match->child_match))
                transformed = true;
              #{"remove_node(match->matched_node); transformed = true;" if condition.removes_node?}
            }
        EOS
      end

      transform_rule += <<-EOS
            match = match->next_match;
          }

          #{rule.code_segment.to_s.gsub '$', 'variable_'}

          return transformed;
        }
      EOS

      "#{transform_child_rules}\n#{transform_rule}"
    end

    def create_node condition
      <<-EOS
        #{create_child_nodes condition.child_rule}

        void create_node_#{condition.object_id}(Match* match) {
          Node* node = (Node*) malloc(sizeof(Node));
          node->parent = match->parent_of_matched_node;
          node->next_sibling = match->matched_node;
          node->previous_sibling = match->previous_sibling_of_matched_node;
          node->children_are_ordered = #{condition.child_rule.conditions_are_ordered?};
          node->children = NULL;
          node->next_in_poset = NULL;
          node->type = #{type_var_for condition.node_type};
          node->value_type = #{condition.value_type};
          #{"node->#{condition.value_type}_value = #{condition.value};" if [:integer, :decimal].include? condition.value_type}

          create_child_nodes_#{condition.child_rule.object_id}(node);

          if (node->previous_sibling)
            node->previous_sibling->next_sibling = node;

          if (node->next_sibling)
            node->next_sibling->previous_sibling = node;

          if (!node->parent->children)
            node->parent->children = node;
          else if (!node->previous_sibling && !node->next_sibling) {
            node->next_sibling = node->parent->children;
            node->next_sibling->previous_sibling = node;
            node->parent->children = node;
          }
        }
      EOS
    end

    def create_child_nodes rule
      create_children_of_child_nodes = ""

      create_child_nodes = <<-EOS
        void create_child_nodes_#{rule.object_id}(Node* parent) {
          Node* previous_sibling = NULL;
          Node* node;
      EOS

      rule.conditions.each do |condition|
        create_children_of_child_nodes += create_child_nodes condition.child_rule
        create_child_nodes += <<-EOS
          node = (Node*) malloc(sizeof(Node));
          node->parent = parent;
          node->next_sibling = NULL;
          node->previous_sibling = previous_sibling;
          node->children_are_ordered = #{condition.child_rule.conditions_are_ordered?};
          node->children = NULL;
          node->next_in_poset = NULL;
          node->type = #{type_var_for condition.node_type};
          node->value_type = #{condition.value_type};
          #{"node->#{condition.value_type}_value = #{condition.value};" if [:integer, :decimal].include? condition.value_type}

          create_child_nodes_#{condition.child_rule.object_id}(node);

          if (previous_sibling)
            previous_sibling->next_sibling = node;
          else
            parent->children = node;

          previous_sibling = node;
        EOS
      end

      create_child_nodes += <<-EOS
        }
      EOS

      "#{create_children_of_child_nodes}\n#{create_child_nodes}"
    end

    def rule_definition_comment rule
      comment = "/*\n"
      rule.definition.each do |line|
        comment += "  #{line} (line #{line.line_number})\n"
      end
      comment + "*/\n"
    end
end
