bool apply_rules(Node* node);
Node* add_to_poset(Node* first_in_poset, Node* node_to_add);

int main() {
  setup_node_types();

  Node* root_parent = new_node(ROOT_PARENT_NODE_TYPE);
  insert(new_node(ROOT_NODE_TYPE), root_parent, NULL);

  Node* first_in_poset = root_parent;
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

  Node* child = root_parent->children->children;
  while (child) {
    child->parent = NULL;
    child = child->next_sibling;
  }

  fprintf(stderr, "No rules to apply!\n");
  print_node(root_parent->children->children, stderr);
  return 1;
}

bool is_ancestor(Node* node, Node* possible_ancestor) {
  while (node && node != possible_ancestor)
    node = node->parent;

  return node != NULL;
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

void remove_node_without_updating_pointers(Node* node) {
  Node* child;
  Node* next_child = node->children;
  while (child = next_child) {
    next_child = child->next_sibling;
    remove_node_without_updating_pointers(child);
  }
  free(node);
}

void remove_node(Node* node) {
  if (node->previous_sibling)
    node->previous_sibling->next_sibling = node->next_sibling;
  if (node->next_sibling)
    node->next_sibling->previous_sibling = node->previous_sibling;
  if (node->parent && node->parent->children == node)
    node->parent->children = node->next_sibling;

  remove_node_without_updating_pointers(node);
}

typedef struct Match {
  long int condition_id;

  struct Match* next_match;
  struct Match* child_match;

  Node* matched_node;
  Node* parent_of_matched_node;
  Node* previous_sibling_of_matched_node;
} Match;

Match* EMPTY_MATCH = (Match*) -1; // TODO: is this ok?

Match* release_match_memory(Match* match) {
  if (match && match != EMPTY_MATCH) {
    release_match_memory(match->next_match);
    release_match_memory(match->child_match);
    free(match);
  }

  return NULL;
}

bool already_matched(Node* node, Match* match) {
  while (match) {
    if (match->matched_node == node)
      return true;
    match = match->next_match;
  }
  return false;
}
