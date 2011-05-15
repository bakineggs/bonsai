#include <stdio.h>

#include "types.h"

#include "parse.h"
#include "print.h"

bool apply(Rule* rule, Node* node);
bool matches(Node* node, Condition* condition);
void transform(Node* node, Condition* condition);

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
  Node* state = parse_nodes(state_file);

  while (apply(rules, state)) {}

  print_node(state);
  return 0;
}

bool apply(Rule* rule, Node* node) {
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
  return false;
}

void transform(Node* node, Condition* condition) {
}
