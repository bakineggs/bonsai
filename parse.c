#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include "parse.h"

Rule* parse_rule(FILE* file);
Condition* parse_condition(char* line, Rule* rule, Condition* previous);
int rule_depth(Rule* rule);
bool ancestor_creates_node(Condition* condition);
bool ancestor_removes_node(Condition* condition);
bool ancestor_prevents_rule(Condition* condition);
void append_condition(Condition* condition, Condition** list);
bool condition_included(Condition* condition, Condition** list);

Node* parse_node(char* line, Node* previous);
int node_depth(Node* node);

void error(char* message, char* line, char* line_position);

char* node_type_for(char** line_position, char* current_line);
char* parse_words(char** line_position, char* current_line);

char* get_line(FILE* file);
int line_number(char* line);
bool is_blank(char* line);

Rule* parse_rules(FILE* file) {
  Rule* first = parse_rule(file);
  if (!first)
    error("At least one rule must be specified", NULL, NULL);

  Rule* current = first;
  while (current->next = parse_rule(file))
    current = current->next;

  return first;
}

Rule* parse_rule(FILE* file) {
  char* line;
  do {
    if (feof(file))
      return NULL;
    line = get_line(file);
  } while (is_blank(line));

  Rule* rule = (Rule*) malloc(sizeof(Rule));
  rule->exact = false;
  rule->ordered = false;
  rule->parent = NULL;
  rule->preventing = NULL;
  rule->matching_single = NULL;
  rule->matching_multiple = NULL;
  rule->creating = NULL;

  Rule* current = rule;
  Condition* condition = NULL;
  do {
    condition = parse_condition(line, current, condition);
    current = condition->children;
    line = get_line(file);
  } while (!is_blank(line));

  return rule;
}

Condition* parse_condition(char* line, Rule* rule, Condition* previous) {
  Condition* condition = (Condition*) malloc(sizeof(Condition));
  condition->next = NULL;

  condition->children = (Rule*) malloc(sizeof(Rule));;
  condition->children->next = NULL;
  condition->children->parent = condition;

  char* position = line;

  int depth = 0;
  while (strncmp(position, "  ", 2) == 0) {
    depth++;
    position += 2;
  }

  if (*position == ' ')
    error("Space before node name", line, position);

  if (depth > rule_depth(rule))
    error("Condition at depth more than one level below its parent", line, NULL);

  while (rule_depth(rule) > depth) {
    rule = previous->rule;
    previous = rule->parent;
  }
  condition->rule = rule;

  char operation = *position;
  condition->removes_node = operation == '-';
  bool matches_node = operation != '+' && operation != '!' && !ancestor_creates_node(condition);

  if (ancestor_removes_node(condition) && (operation == '+' || operation == '-'))
    error("Invalid condition type inside removed node", line, position);

  if (ancestor_creates_node(condition) && (operation == '+' || operation == '-' || operation == '!'))
    error("Invalid condition type inside created node", line, position);

  if (ancestor_prevents_rule(condition) && (operation == '+' || operation == '-'))
    error("Invalid condition type inside condition preventing a rule", line, position);

  if (condition->creates_node = (operation == '+' || ancestor_creates_node(condition)))
    append_condition(condition, &rule->creating);

  if (operation == '!')
    append_condition(condition, &rule->preventing);

  if (operation == '+' || operation == '-' || operation == '!')
    position++;

  condition->node_type = node_type_for(&position, line);

  if (*position++ != ':')
    error("Missing : after node name", line, --position);

  if (condition->children->ordered = *position == ':') {
    position++;
    condition->children->ordered_conditions = NULL;
  } else {
    condition->children->preventing = NULL;
    condition->children->matching_single = NULL;
    condition->children->matching_multiple = NULL;
    condition->children->creating = NULL;
  }

  if (condition->children->exact = *position == '=') {
    position++;

    if (ancestor_creates_node(condition))
      error("Invalid condition type inside created node", line, --position);
  }

  if (*position == '*') {
    position++;

    if (!matches_node)
      error("Multiplicity defined for non-matched node", line, --position);

    append_condition(condition, &rule->matching_multiple);
  } else if (matches_node)
    append_condition(condition, &rule->matching_single);

  condition->variable = NULL;
  if (*position == ' ') {
    position++;
    // TODO: parse variable names and code fragments
  }

  return condition;
}

int rule_depth(Rule* rule) {
  int depth = 0;
  while (rule->parent) {
    rule = rule->parent->rule;
    depth++;
  }
  return depth;
}

bool ancestor_creates_node(Condition* condition) {
  while (condition) {
    if (condition_included(condition, &condition->rule->creating))
      return true;
    condition = condition->rule->parent;
  }

  return false;
}

bool ancestor_removes_node(Condition* condition) {
  while (condition = condition->rule->parent)
    if (condition->removes_node)
      return true;

  return false;
}

bool ancestor_prevents_rule(Condition* condition) {
  while (condition) {
    if (condition_included(condition, &condition->rule->preventing))
      return true;
    condition = condition->rule->parent;
  }

  return false;
}

void append_condition(Condition* condition, Condition** list) {
  if (!*list)
    *list = condition;
  else {
    Condition* current = *list;
    while (current->next)
      current = current->next;
    current->next = condition;
  }
}

bool condition_included(Condition* condition, Condition** list) {
  Condition* current = *list;
  while (current) {
    if (condition == current)
      return true;
    current = current->next;
  }

  return false;
}

Node* parse_nodes(FILE* file) {
  char* line;
  Node* first = NULL;
  Node* node = NULL;

  while (!is_blank(line = get_line(file))) {
    node = parse_node(line, node);

    if (!first)
      first = node;
  }

  if (!first)
    error("No nodes specified", NULL, NULL);

  return first;
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
    error("Space before node name", line, position);

  if (depth == 0) {
    if (previous) {
      while (previous->parent)
        previous = previous->parent;
      previous->next = node;
      node->previous = previous;
    }
    node->parent = NULL;
  } else if (depth > node_depth(previous) + 1)
    error("Node at depth more than one level below its parent", line, NULL);
  else {
    while (node_depth(previous) >= depth)
      previous = previous->parent;
    node->parent = previous;

    if (!previous->children) {
      if (previous->integer_value || previous->decimal_value || previous->string_value)
        error("Can't have child of node with a value", line, NULL);
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
    error("Missing : after node name", line, --position);

  if (node->ordered = *position == ':')
    position++;

  if (*position++ == ' ') {
    if (*position >= '0' && *position <= '9') {
      if (node->ordered)
        error("Ordered nodes can't have values", line, position);

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
          error("Expected comment after spaces at end of line", line, endptr);
      }
      if (*endptr != '\n')
        error("Unexpected character after number", line, endptr);
    } else if (*position == '"') {
      if (node->ordered)
        error("Ordered nodes can't have values", line, position);
      // TODO: parse string values
    } else {
      while (*position == ' ')
        position++;
      if (*position != '#')
        error("Expected comment after spaces at end of line", line, position);
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

void error(char* message, char* line, char* line_position) {
  if (line)
    fprintf(stderr, "Parse Error (line %d): %s\n", line_number(line), message);
  else
    fprintf(stderr, "Parse Error: %s\n", message);

  if (line && strcmp(line, "\n") != 0) {
    fprintf(stderr, "%s", line);

    if (line_position) {
      while (line != line_position) {
        fprintf(stderr, " ");
        line++;
      }
      fprintf(stderr, "^\n");
    }
  }

  exit(1);
}

char* wildcard = "*";
char* node_type_for(char** line_position, char* current_line) {
  if (**line_position == '*') {
    (*line_position)++;
    return wildcard;
  }
  return parse_words(line_position, current_line);
}

char** words;
int words_length = 0;
int words_capacity = 0;
char* parse_words(char** line_position, char* current_line) {
  size_t length = strspn(*line_position, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 ");
  if (length == 0)
    error("Expected words", current_line, *line_position);

  char* start_of_name = *line_position;
  *line_position += length;

  int i; for (i = 0; i < words_length; i++)
    if (strlen(words[i]) == length && strncmp(words[i], start_of_name, length) == 0)
      return words[i];

  if (words_length == words_capacity) {
    words_capacity += 64;
    char** new_words = (char**) malloc(words_capacity * sizeof(char*));
    int i; for (i = 0; i < words_length; i++)
      new_words[i] = words[i];
    free(words);
    words = new_words;
  }

  char* type = words[words_length++] = (char*) malloc(length);
  strncpy(type, start_of_name, length);
  return type;
}

int current_size = 0;
int current_line_number[8];
FILE* current_file[8];
char* current_line[8];
void set_current_line(FILE* file, char* line) {
  int i; for (i = 0; i < current_size; i++)
    if (current_file[i] == file) {
      current_line_number[i]++;
      current_line[i] = line;
      return;
    }

  if (current_size == 8)
    error("Too many files open", NULL, NULL);

  current_file[current_size] = file;
  current_line[current_size] = line;
  current_line_number[current_size] = 1;
  current_size++;
}

const int chars_per_read = 80;
char* get_line(FILE* file) {
  char* line = "";
  int size = 1;

  do {
    size += chars_per_read - 1;
    char* new_line = (char*) malloc(size * sizeof(char));
    strcpy(new_line, line);
    line = new_line;

    if (!fgets(line + (size - chars_per_read), chars_per_read, file)) {
      if (ferror(file))
        error("Error reading file", NULL, NULL);
      else
        break;
    }
  } while (line[strlen(line) - 1] != '\n');

  set_current_line(file, line);

  return line;
}

int line_number(char* line) {
  int i; for (i = 0; i < current_size; i++)
    if (current_line[i] == line)
      return current_line_number[i];
  return 0;
}

bool is_blank(char* line) {
  if (*line == '\n' || *line == '\0')
    return true;

  while (*line == ' ')
    line++;

  return *line == '#';
}

void parsing_done() {
  free(words);
}
