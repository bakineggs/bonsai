#include <stdlib.h>
#include <stdio.h>

#include "types.h"

#include "parse.h"
#include "print.h"

bool apply(Rule* rule, Node* node);

Match* matches(Node* node, Rule* rule);
bool condition_matches_any_child(Condition* condition, Node* node);
bool condition_must_match_one_unmatched_child(Match** match, Condition* condition, Node* node);
void condition_may_match_multiple_unmatched_children(Match** match, Condition* condition, Node* node);
bool condition_matches_node(Condition* condition, Node* node);
bool node_matched(Match* match, Node* node);
void add_match(Match** match, Condition* condition, Node* node, Node* parent);
void add_other_match(Match* match, Condition* condition, Node* node);
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
  Match* match = NULL;

  Condition* preventing = rule->preventing;
  while (preventing) {
    if (condition_matches_any_child(preventing, node))
      return NULL;
    preventing = preventing->next;
  }

  Condition* matching = rule->matching_single;
  while (matching) {
    if (!condition_must_match_one_unmatched_child(&match, matching, node))
      return NULL;
    matching = matching->next;
  }

  if (match)
    while (match->other)
      match = release_match_memory(match);

  matching = rule->matching_multiple;
  while (matching) {
    condition_may_match_multiple_unmatched_children(&match, matching, node);
    matching = matching->next;
  }

  matching = rule->creating;
  while (matching) {
    add_match(&match, matching, node->children, node);
    matching = matching->next;
  }

  if (!match) {
    match = (Match*) malloc(sizeof(Match));
    match->other = NULL;
    match->next = NULL;
    match->condition = NULL;
    match->node = NULL;
    match->parent = NULL;
  }

  return match;
}

bool condition_matches_any_child(Condition* condition, Node* node) {
  Node* child = node->children;
  while (child) {
    if (condition_matches_node(condition, child))
      return true;
    child = child->next;
  }
  return false;
}

bool condition_must_match_one_unmatched_child(Match** match, Condition* condition, Node* node) {
  if (*match) {
    Match* previous_match = NULL;
    Match* current_match = *match;
    while (current_match) {
      bool matched = false;
      Node* child = node->children;
      while (child) {
        if (!node_matched(*match, child) && condition_matches_node(condition, child)) {
          if (!matched) {
            add_match(&current_match, condition, child, node);
            if (!previous_match)
              *match = current_match;
            else
              previous_match->other = current_match;
            matched = true;
          } else {
            add_other_match(current_match, condition, child);
            current_match = current_match->other;
          }
        }
        child = child->next;
      }
      if (matched)
        current_match = (previous_match = current_match)->other;
      else if (current_match == *match)
        *match = current_match = release_match_memory(current_match);
      else
        previous_match->other = current_match = release_match_memory(current_match);
    }
  } else {
    Node* child = node->children;
    while (child) {
      if (condition_matches_node(condition, child)) {
        if (!*match)
          add_match(match, condition, child, node);
        else
          add_other_match(*match, condition, child);
      }
      child = child->next;
    }
  }
  return *match != NULL;
}

void condition_may_match_multiple_unmatched_children(Match** match, Condition* condition, Node* node) {
  Node* child = node->children;
  while (child) {
    if (!node_matched(*match, child) && condition_matches_node(condition, child))
      add_match(match, condition, child, node);
    child = child->next;
  }
}

bool condition_matches_node(Condition* condition, Node* node) {
  if (!node || node->type != condition->node_type)
    return false;

  if (condition->children) {
    Match* match = matches(node, condition->children);
    if (match)
      while (match)
        match = release_match_memory(match);
    else
      return false;
  }

  return true;
}

bool node_matched(Match* match, Node* node) {
  while (match) {
    if (match->node == node)
      return true;
    match = match->next;
  }
  return false;
}

void add_match(Match** match, Condition* condition, Node* node, Node* parent) {
  Match* new = (Match*) malloc(sizeof(Match));
  if (*match) {
    new->other = (*match)->other;
    (*match)->other = NULL;
  } else
    new->other = NULL;
  new->next = *match;
  new->condition = condition;
  new->node = node;
  new->parent = parent;
  *match = new;
}

void add_other_match(Match* match, Condition* condition, Node* node) {
  while (match->other)
    match = match->other;
  match->other = (Match*) malloc(sizeof(Match));
  match->other->other = NULL;
  match->other->next = NULL; // TODO: clone match->next
  match->other->condition = condition;
  match->other->node = node;
  match->other->parent = node->parent;
}

Match* release_match_memory(Match* match) {
  Match* other = match->other;

  if (match->next)
    release_match_memory(match->next);

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
    else
      create_child(match->parent, match->condition);
    transformed = true;
  }

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
    node->ordered = condition->children->ordered;

    if (condition->children)
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
