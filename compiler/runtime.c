#define OKK_NODE_BUILDER_H
#ifdef __cplusplus
  extern "C" {
#endif

void set_node(char* variable, Node* value);
void set_integer(char* variable, int value);
void set_real(char* variable, double value);
void set_string(char* variable, char* value);
Node* build_node(char* definition);

#ifdef __cplusplus
  }
#endif

#define OKK_PRINT_H
#ifdef __cplusplus
  extern "C" {
#endif

void print_node(Node* node);

#ifdef __cplusplus
  }
#endif

bool apply_rules(Node* node);
Node* add_to_poset(Node* first_in_poset, Node* node_to_add);

int main() {
  Node* root = build_node("^:");

  Node* first_in_poset = root;
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

  print_node(root);
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

  printf("\n");

  print_node(node->children);
  print_node(node->next_sibling);
}

void set_node(char* variable, Node* value) {}
void set_integer(char* variable, int value) {}
void set_real(char* variable, double value) {}
void set_string(char* variable, char* value) {}

Node* build_node(char* definition) {
  Node* node = (Node*) malloc(sizeof(Node));

  node->parent = NULL;
  node->next_sibling = NULL;
  node->previous_sibling = NULL;

  node->children_are_ordered = false;
  node->children = NULL;

  node->next_in_poset = NULL;

  node->type = "^";

  node->value_type = none;

  return node;
}
