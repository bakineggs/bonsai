#include <stdlib.h>

#include "types.h"
#include "parse.h"

typedef struct MatchedNode {
  struct MatchedNode* next;
  Node* node;
} MatchedNode;

bool equal(Node* first, Node* second);
int count(Node* node);
bool already_matched(MatchedNode* matched, Node* node);
MatchedNode* add_match(MatchedNode* matched, Node* node);
bool properties_equal(Node* first, Node* second);

int main(int argc, char* argv[]) {
  if (argc != 3) {
    fprintf(stderr, "Wrong number of arguments. Usage:\n./state_diff /path/to/first_state.okk /path/to/second_state.okks\n");
    return 1;
  }

  FILE* first_file = fopen(argv[1], "r");
  if (!first_file) {
    fprintf(stderr, "Could not read first state file.\n");
    return 1;
  }

  FILE* second_file = fopen(argv[2], "r");
  if (!first_file) {
    fprintf(stderr, "Could not read second state file.\n");
    return 1;
  }

  Node* first = parse_nodes(first_file);
  Node* second = parse_nodes(second_file);

  if (equal(first, second))
    return 0;
  else
    return 1;
}

bool equal(Node* first, Node* second) {
  if (count(first) != count(second))
    return false;

  MatchedNode* matched = NULL;

  while (first) {
    Node* current = second;
    do {
      if (already_matched(matched, current))
        continue;
      if (properties_equal(first, current) && equal(first->children, current->children))
        break;
    } while (current = current->next);

    if (!current)
      return false;

    matched = add_match(matched, current);
    first = first->next;
  }

  return true;
}

int count(Node* node) {
  int length = 0;

  while (node) {
    length++;
    node = node->next;
  }

  return length;
}

bool already_matched(MatchedNode* matched, Node* node) {
  while (matched) {
    if (matched->node == node)
      return true;
    matched = matched->next;
  }
  return false;
}

MatchedNode* add_match(MatchedNode* matched, Node* node) {
  MatchedNode* match = (MatchedNode*) malloc(sizeof(MatchedNode));
  match->next = matched;
  match->node = node;
  return match;
}

bool properties_equal(Node* first, Node* second) {
  if (first->type != second->type)
    return false;

  if (first->ordered != second->ordered)
    return false;

  if (first->value_type != second->value_type)
    return false;

  if (first->value_type == integer && first->integer_value == second->integer_value)
    return false;

  if (first->value_type == decimal && first->decimal_value == second->decimal_value)
    return false;

  if (first->value_type == string && first->string_value == second->string_value)
    return false;

  return true;
}
