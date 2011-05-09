#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "types.h"
#include "parse.h"

Rule* parse_rules(FILE* file) {
  Rule* first = parse_rule(file);
  if (!first)
    parse_error("At least one rule must be specified", "");

  Rule* current = first;

  while (current->next = parse_rule(file))
    current = current->next;

  current->next = first;

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
    if (!fgets(current_line, 80, file)) {
      if (ferror(file))
        parse_error("Error reading condition", current_line);
      else
        return NULL;
    }
  } while (strcmp(current_line, "\n") == 0);

  Condition* first = NULL;

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

    char* line_position = current_line;

    current_depth = 0;
    while (strncmp(line_position, "  ", 2) == 0) {
      current_depth++;
      line_position += 2;
    }

    if (*line_position == ' ')
      parse_error("Space before node name", current_line);

    if (current_depth == 0) {
      current->parent = NULL;
      current->ancestor_creates_node = false;
      current->ancestor_removes_node = false;
    } else if (current_depth > previous_depth + 1)
      parse_error("Condition at depth more than one level below its parent", current_line);
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

    current->creates_node = *line_position == '+';
    current->removes_node = *line_position == '-';
    current->matches_node = !current->creates_node && *line_position != '!';

    if (current->creates_node || current->removes_node || !current->matches_node)
      line_position++;

    if (current->creates_node && current->ancestor_creates_node)
      parse_error("Redundant + in front of node and ancestor", current_line);
    if (current->removes_node && current->ancestor_removes_node)
      parse_error("Redundant - in front of node and ancestor", current_line);

    size_t type_length = strspn(line_position, VALID_NODE_NAME_CHARS);
    if (type_length == 0)
      parse_error("Missing node name", current_line);

    current->node_type = (char*) malloc(type_length);
    strncpy(current->node_type, line_position, type_length);
    line_position += type_length;

    if (*line_position++ != ':')
      parse_error("Missing : after node name", current_line);

    // TODO: detect ordered, exact, and multiple

    if (!fgets(current_line, 80, file)) {
      if (ferror(file))
        parse_error("Error reading condition", current_line);
      else
        parse_error("End of file reached inside a condition", current_line);
    }
  } while (strcmp(current_line, "\n") != 0);

  return first;
}

Node* parse_nodes(FILE* file) {
  char current_line[80];

  do {
    if (!fgets(current_line, 80, file)) {
      if (ferror(file))
        parse_error("Error reading node", current_line);
      else
        parse_error("No nodes specified", current_line);
    }
  } while (strcmp(current_line, "\n") == 0);

  Node* first = NULL;

  Node* previous;
  int previous_depth;
  Node* current = NULL;
  int current_depth = -1;

  do {
    previous = current;
    previous_depth = current_depth;

    current = (Node*) malloc(sizeof(Node));
    current->next = NULL;
    current->children = NULL;

    if (!first)
      first = current;

    char* line_position = current_line;

    current_depth = 0;
    while (strncmp(line_position, "  ", 2) == 0) {
      current_depth++;
      line_position += 2;
    }

    if (*line_position == ' ')
      parse_error("Space before node name", current_line);

    if (current_depth == 0) {
      current->parent = NULL;
      while (previous->parent)
        previous = previous->parent;
      previous_depth = 0;
      previous->next = current;
    } else if (current_depth > previous_depth + 1)
      parse_error("Node at depth more than one level below its parent", current_line);
    else {
      while (previous_depth >= current_depth) {
        previous = previous->parent;
        previous_depth--;
      }
      current->parent = previous;

      if (!previous->children)
        previous->children = current;
      else {
        Node* child = previous->children;
        while (child->next)
          child = child->next;
        child->next = current;
      }
    }

    size_t type_length = strspn(line_position, VALID_NODE_NAME_CHARS);
    if (type_length == 0)
      parse_error("Missing node name", current_line);

    current->type = (char*) malloc(type_length);
    strncpy(current->type, line_position, type_length);
    line_position += type_length;

    if (*line_position++ != ':')
      parse_error("Missing : after node name", current_line);

    if (!fgets(current_line, 80, file)) {
      if (ferror(file))
        parse_error("Error reading node", current_line);
      else
        return first;
    }
  } while (true);
}

void parse_error(char* message, char* line) {
  fprintf(stderr, "%s", message);
  if (strcmp(line, "") != 0)
    fprintf(stderr, ":\n  %s", line);
  exit(1);
}
