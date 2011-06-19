#include <stdlib.h>
#include <stdio.h>

#include "types.h"

#include "parse.h"
#include "print.h"

bool apply(Rule* rule, Node* node);
bool matches(Node* node, Condition* condition);
void transform(Node* node, Node* parent, Condition* condition);
void remove_node(Node* node);
void release_memory(Node* node);
void create_sibling(Node* node, Condition* condition);
void create_child(Node* parent, Condition* condition);
Node* create_node(Condition* condition);
void runtime_error(char* message);

Node* state;

int main(int argc, char* argv[]) {
  if (argc != 3) {
    fprintf(stderr, "Wrong number of arguments. Usage:\n./interpreter /path/to/rules.okk /path/to/start_state.okks\n");
    return 1;
  }

  FILE* rules_file = fopen(argv[1], "r");
  if (!rules_file) {
    fprintf(stderr, "Could not read rules file.\n");
    return 1;
  }

  FILE* state_file = fopen(argv[2], "r");
  if (!state_file) {
    fprintf(stderr, "Could not read start state file.\n");
    return 1;
  }

  Rule* rules = parse_rules(rules_file);
  state = parse_nodes(state_file);

  while (apply(rules, state)) {}

  print_node(state);
  return 0;
}

bool apply(Rule* rule, Node* node) {
  if (node == NULL)
    return false;

  bool applied = false;

  if (matches(node, rule->conditions)) {
    transform(node, node->parent, rule->conditions);
    applied = true;
  }

  if (node->children && apply(rule, node->children))
    applied = true;

  if (node->next && apply(rule, node->next))
    applied = true;

  if (rule->next && apply(rule->next, node))
    applied = true;

  return applied;
}

bool matches(Node* node, Condition* condition) {
  bool this_matches = false;

  if (!condition->matches_node)
    this_matches = true;
  else if (node && node->type == condition->node_type)
    this_matches = true;

  // TODO: change this to support unordered conditions of rules
  // we'll have to create a one-to-one mapping from conditions to matched nodes in order to know what to transform
  if (condition->next)
    return this_matches && node && matches(node->next, condition->next);

  return this_matches;
}

void transform(Node* node, Node* parent, Condition* condition) {
  Node* next = node ? node->next : NULL;

  if (condition->removes_node)
    remove_node(node);
  else if (condition->creates_node) {
    if (node)
      create_sibling(node, condition);
    else if (parent)
      create_child(parent, condition);
    else if (!state)
      state = create_node(condition);
    else
      runtime_error("Couldn't create node");
  } else if (condition->children)
    transform(node->children, node, condition->children);

  // TODO: change me along with matches() to support unordered conditions of rules
  if (condition->next)
    transform(next, parent, condition->next);
}

void remove_node(Node* node) {
  if (!node)
    runtime_error("Attempting to remove non-existent node");

  if (node->parent && node->parent->children == node)
    node->parent->children = node->next;

  if (node->previous)
    node->previous->next = node->next;

  if (node->next)
    node->next->previous = node->previous;

  if (state == node)
    state = node->next;

  release_memory(node);
}

void release_memory(Node* node) {
  Node* child;
  Node* next = node->children;

  while (child = next) {
    next = child->next;
    release_memory(child);
  }

  free(node);
}

void create_sibling(Node* node, Condition* condition) {
  Node* sibling = create_node(condition);

  if (sibling->next = node->next)
    sibling->next->previous = sibling;

  sibling->previous = node;
  node->next = sibling;
}

void create_child(Node* parent, Condition* condition) {
  if (parent->children)
    runtime_error("Why are we creating a child instead of a sibling?");

  Node* child = parent->children = create_node(condition);
  do { child->parent = parent; } while (child = child->next);
}

Node* create_node(Condition* condition) {
  Node* node = (Node*) malloc(sizeof(Node));
  node->previous = NULL;
  node->next = NULL;
  node->children = NULL;
  node->parent = NULL;
  node->type = condition->node_type;
  node->ordered = condition->ordered;
  node->integer_value = NULL;
  node->decimal_value = NULL;
  node->string_value = NULL;

  if (condition->children)
    create_child(node, condition->children);

  if (condition->ancestor_creates_node && condition->next)
    create_sibling(node, condition->next);

  return node;
}

void runtime_error(char* message) {
  fprintf(stderr, "%s\n", message);
  exit(1);
}
