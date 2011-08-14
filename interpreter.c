#include <stdlib.h>
#include <stdio.h>

#include "types.h"

#include "parse.h"
#include "print.h"

bool apply(Rule* rule, Node* node);
Match* matches(Node* node, Rule* rule);
Match* matches_condition(Node* node, Condition* condition);
Match* create_match(Node* node, Condition* condition);
Match* release_match_memory(Match* match);
bool transform(Match* match);
void remove_node(Node* node);
void release_node_memory(Node* node);
void create_sibling(Node* node, Condition* condition);
void create_child(Node* parent, Condition* condition);
Node* create_node(Condition* condition);
void shouldnt_happen(char* message);

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
  Node* start_state = parse_nodes(state_file);
  parsing_done();

  Node* state = create_node(NULL);
  state->children = start_state;

  Node* child = state->children;
  while (child) {
    child->parent = state;
    child = child->next;
  }

  while (apply(rules, state)) {}

  child = state->children;
  while (child) {
    child->parent = NULL;
    child = child->next;
  }

  print_node(state->children);
  return 0;
}

bool apply(Rule* rule, Node* node) {
  if (node == NULL)
    return false;

  Match* match = matches(node, rule);
  if (match && transform(match))
    return true;

  bool applied = false;

  if (node->children && apply(rule, node->children))
    applied = true;

  if (node->next && apply(rule, node->next))
    applied = true;

  if (node->parent == NULL && rule->next && apply(rule->next, node))
    applied = true;

  return applied;
}

Match* matches(Node* node, Rule* rule) {
  Match* match = matches_condition(node, rule->conditions);
  if (match) {
    Match* parent = create_match(node->parent, NULL);
    parent->children = match;

    Match* child = parent->children;
    while (child) {
      child->parent = parent;
      child = child->next;
    }
  }
  return match;
}

Match* matches_condition(Node* node, Condition* condition) {
  Match* match = create_match(node, condition);

  if (condition->matches_node) {
    match->other = node && node->next ? matches_condition(node->next, condition) : NULL;

    if (!node || node->type != condition->node_type)
      return release_match_memory(match);
    if (condition->children && !(match->children = matches_condition(node->children, condition->children)))
      return release_match_memory(match);

    Match* child = match->children;
    while (child) {
      child->parent = match;
      child = child->next;
    }
  } else if (condition->prevents_rule) {
    if (!node)
      shouldnt_happen("Testing a condition that prevents a rule against a NULL node");

    Node* this = node;
    bool heading_back = true;
    while (this) {
      if (this->type == condition->node_type)
        if (!condition->children || (match->children = matches_condition(this->children, condition->children)))
          return release_match_memory(match);

      if (heading_back && !(this = this->previous)) { // walk to the beginning of the list
        heading_back = false;
        this = node->next;
      } else if (!heading_back) // and then to the end
        this = this->next;
    }
  }

  // TODO: change this (along with match->other) to support unordered conditions of rules
  // we'll have to create a one-to-one mapping from conditions to matched nodes in order to know what to transform
  if (condition->next)
    if (!(match->next = node ? matches_condition(node->next, condition->next) : NULL))
      return release_match_memory(match);

  return match;
}

Match* create_match(Node* node, Condition* condition) {
  Match* match = (Match*) malloc(sizeof(Match));
  match->node = node;
  match->condition = condition;
  match->other = NULL;
  match->next = NULL;
  match->parent = NULL;
  match->children = NULL;
  return match;
}

Match* release_match_memory(Match* match) {
  Match* other = match->other;

  if (match->next)
    release_match_memory(match->next);

  if (match->children)
    release_match_memory(match->children);

  free(match);
  return other;
}

bool transform(Match* match) {
  bool transformed = false;

  if (match->condition->removes_node) {
    remove_node(match->node);
    match->node = NULL;
    transformed = true;
  } else if (match->condition->creates_node) {
    if (match->node)
      create_sibling(match->node, match->condition);
    else if (match->parent && match->parent->node)
      create_child(match->parent->node, match->condition);
    else
      shouldnt_happen("Couldn't create node");
    transformed = true;
  } else if (match->children && transform(match->children))
    transformed = true;

  if (match->next && transform(match->next))
    transformed = true;

  return transformed;
}

void remove_node(Node* node) {
  if (!node)
    shouldnt_happen("Attempting to remove non-existent node");

  if (node->parent && node->parent->children == node)
    node->parent->children = node->next;

  if (node->previous)
    node->previous->next = node->next;

  if (node->next)
    node->next->previous = node->previous;

  release_node_memory(node);
}

void release_node_memory(Node* node) {
  Node* child;
  Node* next = node->children;

  while (child = next) {
    next = child->next;
    release_node_memory(child);
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
    shouldnt_happen("Why are we creating a child instead of a sibling?");

  Node* child = parent->children = create_node(condition);
  do { child->parent = parent; } while (child = child->next);
}

Node* create_node(Condition* condition) {
  Node* node = (Node*) malloc(sizeof(Node));
  node->previous = NULL;
  node->next = NULL;
  node->children = NULL;
  node->parent = NULL;
  node->integer_value = NULL;
  node->decimal_value = NULL;
  node->string_value = NULL;

  if (condition) {
    node->type = condition->node_type;
    node->ordered = condition->ordered;

    if (condition->children)
      create_child(node, condition->children);

    if (condition->ancestor_creates_node && condition->next)
      create_sibling(node, condition->next);
  } else {
    node->type = (char*) malloc(sizeof(char));
    node->ordered = false;
  }

  return node;
}

void shouldnt_happen(char* message) {
  fprintf(stderr, "%s\n", message);
  exit(2);
}
