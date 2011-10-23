require File.dirname(__FILE__) + '/parser'

class Compiler
  def compile program
    apply_rules = "bool apply_rules(Node* node) {\n"

    rules = Parser.new.parse_rules program
    rules.each do |rule|
    end

    apply_rules += "return false;\n}"

    "#{BASE}\n#{apply_rules}"
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
      #define NULL 0
      typedef enum BOOL { false = 0, true = 1 } bool;
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
      void add_to_poset(Node* first_in_poset, Node* node_to_add);
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
              add_to_poset(first_in_poset, node);
              node = node->parent;
            }
          else {
            Node* child = node->children;
            while (child) {
              add_to_poset(first_in_poset, child);
              child = child->next_sibling;
            }
          }
        }

        print_node(&root);
        return 1;
      }

      void add_to_poset(Node* first_in_poset, Node* node_to_add) {
      }

      void print_node(Node* node) {
      }
    EOS
end
