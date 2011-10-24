require File.dirname(__FILE__) + '/parser'

class Compiler
  def compile program
    rules = Parser.new.parse_rules program

    "#{BASE}\n#{apply_rules rules}"
  end

  private
    # Pseudo-code for generated interpreter:
    #
    # Nodes = [^], a poset in which all nodes come before their ancestors
    #
    # until Nodes is empty
    #   Node = shift Nodes
    #
    #   if a rule can be, and is, applied to Node
    #     add Node and its ancestors to Nodes
    #   else
    #     add Node's children to Nodes
    BASE = <<-EOS
      #ifndef __cplusplus
        typedef enum BOOL { false = 0, true = 1 } bool;
      #endif

      #include <stdio.h>

      #ifndef NULL
        #define NULL 0
      #endif

      typedef enum VALUE { none, integer, decimal, string } value;
      typedef struct Node {
        struct Node* parent;
        struct Node* next_sibling;
        struct Node* previous_sibling;

        bool children_are_ordered;
        struct Node* children;

        struct Node* next_in_poset;

        char* type;

        value value_type;
        long int integer_value;
        double decimal_value;
        char* string_value;
      } Node;

      bool apply_rules(Node* node);
      Node* add_to_poset(Node* first_in_poset, Node* node_to_add);
      void print_node(Node* node);

      int main() {
        struct Node root = {
          .parent = NULL,
          .next_sibling = NULL,
          .previous_sibling = NULL,

          .children_are_ordered = false,
          .children = NULL,

          .next_in_poset = NULL,

          .type = "^",

          .value_type = none
        };

        Node* first_in_poset = &root;
        while (first_in_poset) {
          Node* node = first_in_poset;
          first_in_poset = node->next_in_poset;

          if (apply_rules(node))
            while (node) {
              first_in_poset = add_to_poset(first_in_poset, node);
              node = node->parent;
            }
          else {
            Node* child = node->children;
            while (child) {
              first_in_poset = add_to_poset(first_in_poset, child);
              child = child->next_sibling;
            }
          }
        }

        print_node(&root);
        return 1;
      }

      bool is_ancestor(Node* descendant, Node* ancestor) {
        while (descendant) {
          if (descendant == ancestor)
            return true;
          descendant = descendant->parent;
        }

        return false;
      }

      Node* add_to_poset(Node* first_in_poset, Node* node_to_add) {
        Node* previous_in_poset = NULL;
        Node* next_in_poset = first_in_poset;

        while (next_in_poset) {
          if (next_in_poset == node_to_add)
            return first_in_poset;

          if (is_ancestor(node_to_add, next_in_poset))
            break;

          previous_in_poset = next_in_poset;
          next_in_poset = next_in_poset->next_in_poset;
        }

        if (previous_in_poset)
          previous_in_poset->next_in_poset = node_to_add;
        else
          first_in_poset = node_to_add;

        node_to_add->next_in_poset = next_in_poset;

        return first_in_poset;
      }

      void print_node(Node* node) {
        if (!node)
          return;

        Node* ancestor = node->parent;
        while (ancestor) {
          printf("  ");
          ancestor = ancestor->parent;
        }

        printf("%s:", node->type);

        if (node->children_are_ordered)
          printf(":");
        else if (node->value_type == integer)
          printf(" %li", node->integer_value);
        else if (node->value_type == decimal)
          printf(" %f", node->decimal_value);
        else if (node->value_type == string)
          printf(" %s", node->string_value);

        printf("\\n");

        print_node(node->children);
        print_node(node->next_sibling);
      }
    EOS

    def apply_rules rules
      apply_rules = "bool apply_rules(Node* node) {\n"

      rules.each do |rule|
      end

      apply_rules + "return false;\n}"
    end
end
