#include <stdlib.h>
#include <stdio.h>

#include "../types.h"

#include "../parse.h"
#include "../print.h"

Node* node_for_rule(Rule* rule);
Node* node_for_condition(Condition* condition);
Node* node_for_node(Node* node);

Node* create_node(char* name);
Node* create_child(Node* parent, char* name);

void boolean_attribute(Node* node, char* name, bool value);
void string_attribute(Node* node, char* name, char* value);

int main(int argc, char* argv[]) {
  if (argc != 3) {
    fprintf(stderr, "Wrong number of arguments. Usage:\n./parser /path/to/rules.okk /path/to/start_state.okks > /path/to/bootstrapped_start_state.okks\n");
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

  Node* rule_nodes = node_for_rule(rules);
  Node* state_nodes = node_for_node(start_state);

  Node* rule_node = rule_nodes;
  while (rule_node->next) rule_node = rule_node->next;
  rule_node->next = state_nodes;
  state_nodes->previous = rule_node;

  print_node(rule_nodes);
  return 0;
}

Node* node_for_rule(Rule* rule) {
  Node* rule_node = create_node("Rule");
  rule_node->children = node_for_condition(rule->conditions);

  Node* child = rule_node->children;
  do { child->parent = rule_node; } while (child = child->next);

  if (rule->next) {
    Node* next = node_for_rule(rule->next);
    rule_node->next = next;
    next->previous = rule_node;
  }

  return rule_node;
}

Node* node_for_condition(Condition* condition) {
  Node* condition_node = create_node("Condition");

  string_attribute(condition_node, "NodeType", condition->node_type);
  boolean_attribute(condition_node, "CreatesNode", condition->creates_node);
  boolean_attribute(condition_node, "RemovesNode", condition->removes_node);
  boolean_attribute(condition_node, "MatchesNode", condition->matches_node);
  boolean_attribute(condition_node, "PreventsRule", condition->prevents_rule);
  boolean_attribute(condition_node, "Exact", condition->exact);
  boolean_attribute(condition_node, "Ordered", condition->ordered);
  boolean_attribute(condition_node, "Multiple", condition->multiple);

  if (condition->variable)
    string_attribute(condition_node, "Variable", condition->variable);

  if (condition->children) {
    Node* children = create_child(condition_node, "Children");
    children->ordered = condition->ordered;

    Node* child = node_for_condition(condition->children);
    children->children = child;

    do { child->parent = children; } while (child = child->next);
  }

  if (condition->next) {
    Node* next = node_for_condition(condition->next);
    condition_node->next = next;
    next->previous = condition_node;
  }

  return condition_node;
}

Node* node_for_node(Node* node) {
  return create_node("TODO");
}

Node* create_node(char* name) {
  Node* node = (Node*) malloc(sizeof(Node));
  node->type = name;
  node->previous = NULL;
  node->next = NULL;
  node->children = NULL;
  node->parent = NULL;
  node->ordered = false;
  node->integer_value = NULL;
  node->decimal_value = NULL;
  node->string_value = NULL;
  return node;
}

Node* create_child(Node* parent, char* name) {
  Node* child = create_node(name);
  child->parent = parent;

  if (!parent->children)
    parent->children = child;
  else {
    Node* c = parent->children;
    while (c->next) c = c->next;

    c->next = child;
    child->previous = c;
  }

  return child;
}

long int true_value = 1;
long int false_value = 0;
void boolean_attribute(Node* node, char* name, bool value) {
  Node* attribute = create_child(node, name);
  attribute->integer_value = value ? &true_value : &false_value;
}

void string_attribute(Node* node, char* name, char* value) {
  Node* attribute = create_child(node, name);
  attribute->string_value = value;
}
