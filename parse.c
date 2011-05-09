#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "types.h"
#include "parse.h"

Rule* parse_rules(FILE* file) {
  Rule* first = parse_rule(file);
  if (!first)
    parse_error("At least one rule must be specified");

  Rule* current = first;
  while (current) {
    current->next = parse_rule(file);
    current = current->next;
  }

  return first;
}

Rule* parse_rule(FILE* file) {
  Rule* rule = (Rule*) malloc(sizeof(Rule));
  rule->conditions = parse_conditions(file);

  if (!rule->conditions) {
    free(rule);
    return NULL;
  }

  return rule;
}

Condition* parse_conditions(FILE* file) {
  char current_line[80];

  do {
    if (!fgets(current_line, 80, file))
      return NULL;
  } while (strcmp(current_line, "\n") == 0);

  Condition* first;

  Condition* previous;
  int previous_depth;
  Condition* current = NULL;
  int current_depth = -1;

  do {
    previous = current;
    previous_depth = current_depth;

    current = (Condition*) malloc(sizeof(Condition));
    current->next = NULL;
    current->children = NULL;

    if (!first)
      first = current;

    current_depth = 0;
    while (strncmp(current_line + (current_depth * 2), "  ", 2) == 0)
      current_depth++;

    if (current_depth == 0) {
      current->parent = NULL;
      current->ancestor_creates_node = false;
      current->ancestor_removes_node = false;
    }
    else if (current_depth > previous_depth + 1)
      parse_error("Condition at depth more than one level below its parent");
    else {
      while (previous_depth >= current_depth) {
        previous = previous->parent;
        previous_depth--;
      }
      current->parent = previous;
      current->ancestor_creates_node = previous->creates_node || previous->ancestor_creates_node;
      current->ancestor_removes_node = previous->removes_node || previous->ancestor_removes_node;

      if (!previous->children)
        previous->children = current;
      else {
        Condition* child = previous->children;
        while (child->next)
          child = child->next;
        child->next = current;
      }
    }

    int column = current_depth * 2;

    current->creates_node = current_line[column] == '+';
    current->removes_node = current_line[column] == '-';
    current->matches_node = !current->creates_node && current_line[column] != '!';

    if (current->creates_node || current->removes_node || !current->matches_node)
      column++;

    if (current->creates_node && current->ancestor_creates_node)
      parse_error("Redundant + in front of node and ancestor");
    if (current->removes_node && current->ancestor_removes_node)
      parse_error("Redundant - in front of node and ancestor");

    size_t type_length = strcspn(current_line + column, ":");
    current->node_type = (char*) malloc(type_length);
    strncpy(current->node_type, current_line + column, type_length);

    // TODO: detect ordered, exact, and multiple

    if (!fgets(current_line, 80, file)) {
      if (ferror(file))
        parse_error("Error reading condition");
      else
        parse_error("End of file reached inside a condition");
    }
  } while (strcmp(current_line, "\n") != 0);

  return first;
}
