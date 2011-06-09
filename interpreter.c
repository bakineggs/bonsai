#include <stdlib.h>
#include <stdio.h>

#include "types.h"

#include "parse.h"
#include "print.h"

bool apply(Rule* rule, Node* node);
bool matches(Node* node, Condition* condition);
void transform(Node* node, Condition* condition);
void remove_node(Node* node);
void release_memory(Node* node);
void create_sibling(Node* node, Condition* condition);

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
    transform(node, rule->conditions);
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
  else if (node && strcmp(node->type, condition->node_type) == 0)
    this_matches = true;

  // TODO: change this to support unordered conditions of rules
  // we'll have to create a one-to-one mapping from conditions to matched nodes in order to know what to transform
  if (condition->next)
    return this_matches && node && matches(node->next, condition->next);

  return this_matches;
}

void transform(Node* node, Condition* condition) {
  if (condition->removes_node)
    remove_node(node);

  if (condition->creates_node)
    create_sibling(node, condition);

  // TODO: change me along with matches() to support unordered conditions of rules
  if (condition->next)
    transform(node->next, condition->next);
}

void remove_node(Node* node) {
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
  Node* this_child = node->children;
  Node* next_child;

  while (this_child) {
    next_child = this_child->next;
    release_memory(this_child);
    this_child = next_child;
  }

  free(node);
}

void create_sibling(Node* node, Condition* condition) {
  Node* sibling = (Node*) malloc(sizeof(Node));
  sibling->children = NULL;
  sibling->integer_value = NULL;
  sibling->decimal_value = NULL;
  sibling->string_value = NULL;

  if (!state) {
    state = sibling;
    sibling->previous = NULL;
    sibling->next = NULL;
  } else {
    if (sibling->next = node->next)
      sibling->next->previous = sibling;

    sibling->previous = node;
    node->next = sibling;
  }

  sibling->type = condition->node_type;
}
