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

Node* new_node(char* type);
bool apply_rules(Node* node);
Node* add_to_poset(Node* first_in_poset, Node* node_to_add);

int main() {
  Node* root = new_node("^");

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

Node* build_offset_node(char* definition, int depth_offset, Node* previous, int previous_depth);
Node* build_node(char* definition) {
  if (*definition == '\n')
    definition++;

  char* current = definition;
  int depth = 0;
  while (*current == ' ') {
    depth++;
    current++;
  }

  return build_offset_node(definition, depth, NULL, 0);
}

void error(char* message, char* definition) {
  fprintf(stderr, "build_node error: %s\n%s\n", message, definition);
  exit(1);
}

char* node_type_for(char* definition);
Node* build_offset_node(char* definition, int depth_offset, Node* previous, int previous_depth) {
  int depth = 0;
  while (depth < depth_offset && *definition != '\0') {
    definition++;
    depth++;
  }

  depth = 0;
  while (strncmp(definition, "  ", 2) == 0) {
    depth++;
    definition += 2;
  }

  if (*definition == '\0') {
    while (previous->parent)
      previous = previous->parent;
    while (previous->previous_sibling)
      previous = previous->previous_sibling;
    return previous;
  }

  if (*definition == ' ')
    error("Space before node name", definition);

  if (depth > previous_depth + 1)
    error("Node at depth more than one level below its parent", definition);

  while (previous_depth > depth) {
    previous = previous->parent;
    previous_depth--;
  }

  if (*definition == '$') {
    Node* node; // TODO: get node from set variable
    return build_offset_node(definition, depth_offset, node, depth);
  }

  Node* node = new_node(node_type_for(definition));

  if (depth > previous_depth) {
    node->parent = previous;

    previous->children = node;
  } else { // depth == previous_depth
    node->parent = previous->parent;

    node->previous_sibling = previous;
    previous->next_sibling = node;
  }

  node->type = node_type_for(definition);
  definition += strlen(node->type);

  if (*definition != ':')
    error("Missing : after node name", definition);

  if (node->children_are_ordered = *definition == ':')
    definition++;

  if (*definition == ' ' || *definition == '#') {
    if (*definition++ == ' ') {
      if (*definition >= '0' && *definition <= '9') {
        if (node->children_are_ordered)
          error("Nodes with ordered children can't have values", definition);

        char* endptr;
        node->value_type = integer;
        node->integer_value = strtol(definition, &endptr, 10);

        if (*endptr == '.') {
          node->value_type = decimal;
          node->decimal_value = strtod(definition, &endptr);
        }

        if (*endptr != '\n') {
          while (*endptr == ' ')
            endptr++;
          if (*endptr != '#')
            error("Expected comment after spaces at end of line", endptr);
        }
      } else if (*definition == '"') {
        if (node->children_are_ordered)
          error("Nodes with ordered children can't have values", definition);

        // TODO: parse string values
      } else if (*definition == '$') {
        if (node->children_are_ordered)
          error("Nodes with ordered children can't have values", definition);

        // TODO: get value from set variable
      } else {
        while (*definition == ' ')
          definition++;
        if (*definition != '#')
          error("Expected value or comment after spaces at end of line", definition);
      }
    }

    while (*definition != '\n')
      definition++;
  }

  if (*definition != '\n')
    error("Unexpected characters at end of line", definition);

  return build_offset_node(definition, depth_offset, node, depth);
}

char* node_type_for(char* definition) {
  return NULL;
}

Node* new_node(char* type) {
  Node* node = (Node*) malloc(sizeof(Node));

  node->parent = NULL;
  node->next_sibling = NULL;
  node->previous_sibling = NULL;

  node->children_are_ordered = false;
  node->children = NULL;

  node->next_in_poset = NULL;

  node->type = type;

  node->value_type = none;

  return node;
}
