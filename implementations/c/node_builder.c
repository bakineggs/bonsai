#define BONSAI_NODE_BUILDER_H

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "types.h"

void assertion_failure(char* message) {
  fprintf(stderr, "%s\n", message);
  exit(2);
}

void build_node_error(char* message, char* definition) {
  fprintf(stderr, "build_node error: %s\n%s\n", message, definition);
  exit(1);
}

#define BUILD_NODE_VARIABLES_CAPACITY 64
char* build_node_variable_names[BUILD_NODE_VARIABLES_CAPACITY];
value build_node_variable_types[BUILD_NODE_VARIABLES_CAPACITY];
Node* build_node_node_values[BUILD_NODE_VARIABLES_CAPACITY];
int build_node_integer_values[BUILD_NODE_VARIABLES_CAPACITY];
double build_node_decimal_values[BUILD_NODE_VARIABLES_CAPACITY];
char* build_node_string_values[BUILD_NODE_VARIABLES_CAPACITY];
int build_node_variables_length = 0;

int unused_variable_index(char* variable) {
  int i; for (i = 0; i < build_node_variables_length; i++)
    if (strcmp(build_node_variable_names[i], variable) == 0)
      build_node_error("Variable already in use", variable);

  if (build_node_variables_length == BUILD_NODE_VARIABLES_CAPACITY)
    build_node_error("You're seriously using enough variables to fill the table?", variable);

  build_node_variables_length++;
  build_node_variable_names[i] = (char*) malloc(sizeof(char) * (strlen(variable) + 1));
  strcpy(build_node_variable_names[i], variable);
  return i;
}

void set_node(char* variable, Node* value) {
  int i = unused_variable_index(variable);
  build_node_variable_types[i] = none;
  build_node_node_values[i] = value;
}

void set_integer(char* variable, int value) {
  int i = unused_variable_index(variable);
  build_node_variable_types[i] = integer;
  build_node_integer_values[i] = value;
}

void set_decimal(char* variable, double value) {
  int i = unused_variable_index(variable);
  build_node_variable_types[i] = decimal;
  build_node_decimal_values[i] = value;
}

void set_string(char* variable, char* value) {
  int i = unused_variable_index(variable);
  build_node_variable_types[i] = string;
  build_node_string_values[i] = (char*) malloc(sizeof(char) * (strlen(value) + 1));
  strcpy(build_node_string_values[i], value);
}

Node* build_offset_node(char* definition, int depth_offset, Node* previous, int previous_depth);
Node* build_node(char* definition) {
  char* current = definition;
  int depth = 0;
  while (*current == ' ') {
    depth++;
    current++;
  }

  Node* node = build_offset_node(definition, depth, NULL, 0);

  int i; for (i = 0; i < build_node_variables_length; i++)
    free(build_node_variable_names[i]);
  build_node_variables_length = 0;

  return node;
}

Node* new_node(char* type);
void insert(Node* new, Node* parent, Node* next_sibling);
char* node_type_for(char* definition);
Node* build_offset_node(char* definition, int depth_offset, Node* previous, int previous_depth) {
  int depth = 0;
  while (depth < depth_offset && *definition != '\0') {
    definition++;
    depth++;
  }

  depth = 0;
  while (strncmp(definition, "  ", 2) == 0) {
    depth++;
    definition += 2;
  }

  if (*definition == '\0') {
    while (previous->parent)
      previous = previous->parent;
    while (previous->previous_sibling)
      previous = previous->previous_sibling;
    return previous;
  }

  if (*definition == ' ')
    build_node_error("Space before node name", definition);

  if (depth > previous_depth + 1)
    build_node_error("Node at depth more than one level below its parent", definition);

  if (depth > previous_depth && previous->value_type != none)
    build_node_error("Nodes with values can't have children", definition);

  while (previous_depth > depth) {
    previous = previous->parent;
    previous_depth--;
  }

  if (*definition == '$') {
    definition++;

    size_t length = strspn(definition, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789");
    if (length == 0)
      build_node_error("Expected a variable name", definition);

    int i; for (i = 0; i < build_node_variables_length; i++)
      if (strlen(build_node_variable_names[i]) == length && strncmp(build_node_variable_names[i], definition, length) == 0)
        break;

    if (i == build_node_variables_length)
      build_node_error("Variable name not found", definition);

    if (build_node_variable_types[i] != none)
      build_node_error("Variable is not a node", definition);

    definition += length;

    if (*definition != '\n' && *definition != '\0')
      build_node_error("Unexpected characters after variable", definition);

    if (*definition == '\n')
      definition++;

    if (previous != NULL && build_node_node_values[i] != NULL) {
      insert(build_node_node_values[i], depth > previous_depth ? previous : previous->parent, NULL);
    }

    return build_offset_node(definition, depth_offset, build_node_node_values[i] != NULL ? build_node_node_values[i] : previous, depth);
  }

  Node* node = new_node(node_type_for(definition));

  if (previous != NULL)
    insert(node, depth > previous_depth ? previous : previous->parent, NULL);

  node->type = node_type_for(definition);
  definition += strlen(node->type);

  if (*definition != ':')
    build_node_error("Missing : after node name", definition);

  definition++;

  if ((node->children_are_ordered = *definition == ':'))
    definition++;

  if (*definition == ' ') {
    definition++;

    if (*definition >= '0' && *definition <= '9') {
      if (node->children_are_ordered)
        build_node_error("Nodes with ordered children can't have values", definition);

      char* endptr;
      node->value_type = integer;
      node->integer_value = strtol(definition, &endptr, 10);

      if (*endptr == '.') {
        node->value_type = decimal;
        node->decimal_value = strtod(definition, &endptr);
      }

      if (*endptr != '\n' && *endptr != '\0')
        build_node_error("Unexpected characters after value", endptr);
    } else if (*definition == '"') {
      if (node->children_are_ordered)
        build_node_error("Nodes with ordered children can't have values", definition);

      // TODO: parse string values
      build_node_error("I haven't implemented parsing strings yet", definition);
    } else if (*definition == '$') {
      if (node->children_are_ordered)
        build_node_error("Nodes with ordered children can't have values", definition);

      size_t length = strspn(++definition, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789");
      if (length == 0)
        build_node_error("Expected a variable name", definition);

      int i; for (i = 0; i < build_node_variables_length; i++)
        if (strlen(build_node_variable_names[i]) == length && strncmp(build_node_variable_names[i], definition, length) == 0)
          break;

      if (i == build_node_variables_length)
        build_node_error("Variable name not found", definition);

      if (build_node_variable_types[i] == none)
        build_node_error("Variable is a node", definition);

      definition += length;

      if (*definition != '\n' && *definition != '\0')
        build_node_error("Unexpected characters after variable", definition);

      node->value_type = build_node_variable_types[i];
      if (node->value_type == integer)
        node->integer_value = build_node_integer_values[i];
      else if (node->value_type == decimal)
        node->decimal_value = build_node_decimal_values[i];
      else if (node->value_type == string)
        node->string_value = build_node_string_values[i];
    } else
      build_node_error("Expected value after space proceeding node type", definition);
  }

  if (*definition != '\n' && *definition != '\0')
    build_node_error("Unexpected characters at end of line", definition);

  if (*definition == '\n')
    definition++;

  return build_offset_node(definition, depth_offset, node, depth);
}

char** node_types;
int node_types_length = 0;
int node_types_capacity = 0;
char* node_type_for(char* definition) {
  size_t length = strspn(definition, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 ");
  if (length == 0)
    build_node_error("Expected a node type", definition);

  int i; for (i = 0; i < node_types_length; i++)
    if (strlen(node_types[i]) == length && strncmp(node_types[i], definition, length) == 0)
      return node_types[i];

  if (node_types_length == node_types_capacity) {
    node_types_capacity += 64;
    char** new_node_types = (char**) malloc(node_types_capacity * sizeof(char*));

    int i; for (i = 0; i < node_types_length; i++)
      new_node_types[i] = node_types[i];

    free(node_types);
    node_types = new_node_types;
  }

  char* node_type = node_types[node_types_length++] = (char*) malloc(length + 1);
  strncpy(node_type, definition, length);
  node_type[length] = '\0';
  return node_type;
}

Node* new_node(char* type) {
  Node* node = (Node*) malloc(sizeof(Node));

  node->parent = NULL;
  node->next_sibling = NULL;
  node->previous_sibling = NULL;

  node->children_are_ordered = false;
  node->children = NULL;

  node->next_in_poset = NULL;

  node->type = type;

  node->value_type = none;

  return node;
}

void insert(Node* new, Node* parent, Node* next_sibling) {
  Node* last_new_sibling;
  Node* sibling = new;
  while (sibling) {
    last_new_sibling = sibling;
    sibling->parent = parent;
    sibling = sibling->next_sibling;
  }

  if (!parent->children) {
    if (next_sibling)
      assertion_failure("insert(): next_sibling provided with a parent with no children");

    parent->children = new;
    return;
  }

  if (!next_sibling) { // insert at end
    Node* previous_sibling = parent->children;
    while (previous_sibling->next_sibling)
      previous_sibling = previous_sibling->next_sibling;
    new->previous_sibling = previous_sibling;
    previous_sibling->next_sibling = new;
    return;
  }

  if (next_sibling->parent != parent)
    assertion_failure("insert(): next_sibling->parent != parent");

  if ((new->previous_sibling = next_sibling->previous_sibling))
    new->previous_sibling->next_sibling = new;
  else
    parent->children = new;

  next_sibling->previous_sibling = last_new_sibling;
  last_new_sibling->next_sibling = next_sibling;
}
