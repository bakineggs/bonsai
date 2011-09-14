#include <stdlib.h>
#include <stdio.h>

#include "types.h"

#include "parse.h"
#include "print.h"

bool apply(Rule* rule, Node* node);

Match* matches(Rule* rule, Node* node);

bool matches_any_child(Condition* condition, Node* node);
Match* must_match_one_unmatched_child(Match* matches, Condition* condition, Node* node);
Match* must_match_one_child(Condition* condition, Node* node);
Match* may_match_many_unmatched_children(Match* matches, Condition* condition, Node* node);
Match* may_match_many_children(Condition* condition, Node* node);
Match* matches_this_node(Condition* condition, Node* node);

bool matched(Match* matches, Node* node);
Match* add_match(Match* matches, Condition* condition, Node* node);
Match* append_match(Match* matches, Match* match);
Match* clone_match(Match* match);
Match* release_this_match(Match* match);
Match* release_other_matches(Match* match);
void release_all_matches(Match* match);

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
  Match* match = matches(rule, node);
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

Match* matches(Rule* rule, Node* node) {
  Condition* preventing = rule->preventing;
  while (preventing) {
    if (matches_any_child(preventing, node))
      return NULL;
    preventing = preventing->next;
  }

  Match* match = NULL;

  Condition* matching = rule->matching_single;
  while (matching) {
    if (!(match = must_match_one_unmatched_child(match, matching, node)))
      return NULL;
    matching = matching->next;
  }

  matching = rule->matching_multiple;
  while (matching) {
    match = may_match_many_unmatched_children(match, matching, node);
    matching = matching->next;
  }

  Condition* creating = rule->creating;
  while (creating) {
    match = add_match(match, creating, node);
    creating = creating->next;
  }

  return release_other_matches(add_match(match, NULL, node));
}

bool matches_any_child(Condition* condition, Node* node) {
  Match* match;
  Node* child = node->children;
  while (child) {
    if (match = matches_this_node(condition, child)) {
      release_all_matches(match);
      return true;
    }
    child = child->next;
  }
  return false;
}

Match* must_match_one_unmatched_child(Match* matches, Condition* condition, Node* node) {
  if (!matches)
    return must_match_one_child(condition, node);

  if (matches && matches->other)
    matches->other = must_match_one_unmatched_child(matches->other, condition, node);

  Match* match;
  Node* child = node->children;
  while (child) {
    if (!matched(matches, child) && (match = matches_this_node(condition, child))) {
      Match* new = clone_match(matches);
      new->other = matches;
      append_match(matches, match);
      matches = new;
    }
    child = child->next;
  }

  match = matches->other;
  matches->other = NULL;
  release_all_matches(matches);
  return match;
}

Match* must_match_one_child(Condition* condition, Node* node) {
  Match* matches = NULL;
  Match* match;
  Node* child = node->children;
  while (child) {
    if (match = matches_this_node(condition, child)) {
      match->other = matches;
      matches = match;
    }
    child = child->next;
  }

  return matches;
}

Match* may_match_many_unmatched_children(Match* matches, Condition* condition, Node* node) {
  if (!matches)
    return may_match_many_children(condition, node);

  if (matches->other)
    matches->other = may_match_many_unmatched_children(matches->other, condition, node);

  Match* match;
  Node* child = node->children;
  while (child) {
    if (!matched(matches, child) && (match = matches_this_node(condition, child)))
      append_match(matches, match);
    child = child->next;
  }

  return matches;
}

Match* may_match_many_children(Condition* condition, Node* node) {
  Match* matches = NULL;
  Match* match;
  Node* child = node->children;
  while (child) {
    if (match = matches_this_node(condition, child))
      matches = append_match(match, matches);
    child = child->next;
  }

  return matches;
}

Match* matches_this_node(Condition* condition, Node* node) {
  if (!node || node->type != condition->node_type)
    return NULL;

  Match* match = NULL;
  if (condition->children && !(match = matches(condition->children, node)))
    return NULL;

  if (condition->removes_node) {
    release_all_matches(match);
    match = NULL;
  }

  return add_match(match, condition, node);
}

bool matched(Match* matches, Node* node) {
  while (matches) {
    if (matches->node == node)
      return true;
    matches = matches->next;
  }
  return false;
}

Match* add_match(Match* matches, Condition* condition, Node* node) {
  Match* new = (Match*) malloc(sizeof(Match));
  if (matches) {
    new->other = matches->other;
    matches->other = NULL;
  } else
    new->other = NULL;
  new->next = matches;
  new->condition = condition;
  new->node = node;
  return new;
}

Match* append_match(Match* matches, Match* match) {
  Match* current = matches;
  while (current->next)
    current = current->next;
  current->next = match;
  return matches;
}

Match* clone_match(Match* match) {
  if (!match)
    return NULL;

  Match* clone = (Match*) malloc(sizeof(Match));
  clone->other = match->other;
  clone->next = clone_match(match->next);
  clone->condition = match->condition;
  clone->node = match->node;
  return clone;
}

Match* release_this_match(Match* match) {
  Match* other = match->other;

  if (match->next)
    release_all_matches(match->next);

  free(match);
  return other;
}

Match* release_other_matches(Match* match) {
  release_all_matches(match->other);
  match->other = NULL;
  return match;
}

void release_all_matches(Match* match) {
  while (match)
    match = release_this_match(match);
}

bool transform(Match* match) {
  bool transformed = false;

  if (match->condition && match->condition->removes_node) {
    remove_node(match->node);
    match->node = NULL;
    transformed = true;
  } else if (match->condition && match->condition->creates_node) {
    create_child(match->node, match->condition);
    transformed = true;
  }

  if (match->next && transform(match->next))
    transformed = true;

  free(match);
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

  sibling->previous = node;
  sibling->parent = node->parent;

  while (sibling->next) {
    sibling = sibling->next;
    sibling->parent = node->parent;
  }

  if (sibling->next = node->next)
    sibling->next->previous = sibling;

  node->next = sibling;
}

void create_child(Node* parent, Condition* condition) {
  if (parent->children)
    return create_sibling(parent->children, condition);

  Node* child = parent->children = create_node(condition);
  do { child->parent = parent; } while (child = child->next);
}

Node* create_node(Condition* condition) {
  Node* node = (Node*) malloc(sizeof(Node));
  node->previous = NULL;
  node->next = NULL;
  node->children = NULL;
  node->parent = NULL;
  node->value_type = none;

  if (condition) {
    node->type = condition->node_type;
    node->ordered = condition->children->ordered;

    if (condition->children->creating)
      create_child(node, condition->children->creating);

    if (condition->next)
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
