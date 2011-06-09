#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "parse.h"

Rule* parse_rule(FILE* file);
Condition* parse_conditions(FILE* file);
Condition* parse_condition(char* line, Condition* previous); // TODO
int condition_depth(Condition* condition); // TODO

Node* parse_node(char* line, Node* previous);
int node_depth(Node* node);

void error(char* message, char* line);
char* node_type_for(char** line_position, char* current_line);

Rule* parse_rules(FILE* file) {
  Rule* first = parse_rule(file);
  if (!first)
    error("At least one rule must be specified", "");

  Rule* current = first;

  while (current->next = parse_rule(file))
    current = current->next;

  current->next = NULL;

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
        error("Error reading condition", current_line);
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

    char* line_position = current_line;

    current_depth = 0;
    while (strncmp(line_position, "  ", 2) == 0) {
      current_depth++;
      line_position += 2;
    }

    if (*line_position == ' ')
      error("Space before node name", current_line);

    if (current_depth == 0) {
      if (!first)
        first = current;
      else {
        while (previous->parent)
          previous = previous->parent;
        previous->next = current;
        previous_depth = 0;
      }
      current->parent = NULL;
      current->ancestor_creates_node = false;
      current->ancestor_removes_node = false;
    } else if (current_depth > previous_depth + 1)
      error("Condition at depth more than one level below its parent", current_line);
    else {
      while (previous_depth >= current_depth) {
        previous = previous->parent;
        previous_depth--;
      }
      current->parent = previous;
      current->ancestor_creates_node = previous->creates_node || previous->ancestor_creates_node;
      current->ancestor_removes_node = previous->removes_node || previous->ancestor_removes_node;

      if (!previous->children) {
        if (previous->variable)
          error("Can't have child of node assigned to variable", current_line);
        previous->children = current;
      } else {
        Condition* child = previous->children;
        while (child->next)
          child = child->next;
        child->next = current;
      }
    }

    current->creates_node = *line_position == '+';
    current->removes_node = *line_position == '-';
    current->excludes_node = *line_position == '!';
    current->matches_node = !current->ancestor_creates_node && !current->creates_node && !current->excludes_node;

    if (current->creates_node || current->removes_node || current->excludes_node)
      line_position++;

    if (current->creates_node && current->ancestor_creates_node)
      error("Redundant + in front of node and ancestor", current_line);
    if (current->removes_node && current->ancestor_removes_node)
      error("Redundant - in front of node and ancestor", current_line);

    current->node_type = node_type_for(&line_position, current_line);

    if (*line_position++ != ':')
      error("Missing : after node name", current_line);

    if (current->ordered = *line_position == ':')
      line_position++;

    if (current->exact = *line_position == '=')
      line_position++;

    if (current->multiple = *line_position == '*')
      line_position++;

    if (current->multiple && !current->matches_node)
      error("Multiplicity defined for non-matched node", current_line);

    if (!fgets(current_line, 80, file)) {
      if (ferror(file))
        error("Error reading condition", current_line);
      else
        return first;
    }
  } while (strcmp(current_line, "\n") != 0);

  return first;
}

Node* parse_nodes(FILE* file) {
  char line[80];

  do {
    if (!fgets(line, 80, file)) {
      if (ferror(file))
        error("Error reading node", line);
      else
        error("No nodes specified", line);
    }
  } while (strcmp(line, "\n") == 0);

  Node* first = NULL;
  Node* node = NULL;

  do {
    node = parse_node(line, node);

    if (!first)
      first = node;

    if (!fgets(line, 80, file)) {
      if (ferror(file))
        error("Error reading node", line);
      else
        return first;
    }
  } while (true);
}

Node* parse_node(char* line, Node* previous) {
  Node* node = (Node*) malloc(sizeof(Node));
  node->previous = NULL;
  node->next = NULL;
  node->children = NULL;
  node->integer_value = NULL;
  node->decimal_value = NULL;
  node->string_value = NULL;

  char* position = line;

  int depth = 0;
  while (strncmp(position, "  ", 2) == 0) {
    depth++;
    position += 2;
  }

  if (*position == ' ')
    error("Space before node name", line);

  if (depth == 0) {
    if (previous) {
      while (previous->parent)
        previous = previous->parent;
      previous->next = node;
      node->previous = previous;
    }
    node->parent = NULL;
  } else if (depth > node_depth(previous) + 1)
    error("Node at depth more than one level below its parent", line);
  else {
    while (node_depth(previous) >= depth)
      previous = previous->parent;
    node->parent = previous;

    if (!previous->children) {
      if (previous->integer_value || previous->decimal_value || previous->string_value)
        error("Can't have child of node with a value", line);
      previous->children = node;
    } else {
      Node* child = previous->children;
      while (child->next)
        child = child->next;
      node->previous = child;
      child->next = node;
    }
  }

  node->type = node_type_for(&position, line);

  if (*position++ != ':')
    error("Missing : after node name", line);

  if (node->ordered = *position == ':')
    position++;

  if (*position++ == ' ') {
    if (node->ordered)
      error("Ordered nodes can't have values", line);

    if (*position >= '0' && *position <= '9') {
      char* endptr;
      node->integer_value = (long int*) malloc(sizeof(long int));
      *node->integer_value = strtol(position, &endptr, 10);
      if (*endptr == '.') {
        free(node->integer_value);
        node->integer_value = NULL;
        node->decimal_value = (double*) malloc(sizeof(double));
        *node->decimal_value = strtod(position, &endptr);
      }
      if (*endptr == ' ') {
        while (*endptr == ' ')
          endptr++;
        if (*endptr != '#')
          error("Expected comment after spaces at end of line", line);
      }
      if (*endptr != '\n')
        error("Unexpected character after number", line);
    } else {
      // TODO: parse string values
    }
  }

  return node;
}

int node_depth(Node* node) {
  int depth = 0;
  while (node = node->parent)
    depth++;
  return depth;
}

void error(char* message, char* line) {
  fprintf(stderr, "Parse Error: %s", message);
  if (strcmp(line, "") != 0)
    fprintf(stderr, ":\n  %s", line);
  exit(1);
}

char** node_types; // this could be freed when we're done parsing
int node_types_length = 0;
int node_types_capacity = 0;
char* node_type_for(char** line_position, char* current_line) {
  size_t length = strspn(*line_position, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 ");
  if (length == 0)
    error("Missing node name", current_line);

  char* start_of_name = *line_position;
  *line_position += length;

  int i; for (i = 0; i < node_types_length; i++)
    if (strncmp(node_types[i], start_of_name, length) == 0)
      return node_types[i];

  if (node_types_length == node_types_capacity) {
    node_types_capacity += 64;
    char** new_node_types = (char**) malloc(node_types_capacity * sizeof(char*));
    int i; for (i = 0; i < node_types_length; i++)
      new_node_types[i] = node_types[i];
    free(node_types);
    node_types = new_node_types;
  }

  char* type = node_types[node_types_length++] = (char*) malloc(length);
  strncpy(type, start_of_name, length);
  return type;
}
