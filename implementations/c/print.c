#define BONSAI_PRINT_H

#include <stdio.h>
#include "types.h"

void print_node(Node* node, FILE* stream) {
  if (!node)
    return;

  Node* ancestor = node->parent;
  while (ancestor) {
    fprintf(stream, "  ");
    ancestor = ancestor->parent;
  }

  fprintf(stream, "%s:", node->type);

  if (node->children_are_ordered)
    fprintf(stream, ":");
  else if (node->value_type == integer)
    fprintf(stream, " %li", node->integer_value);
  else if (node->value_type == decimal)
    fprintf(stream, " %f", node->decimal_value);
  else if (node->value_type == string)
    fprintf(stream, " \"%s\"", node->string_value);

  fprintf(stream, "\n");

  print_node(node->children, stream);
  print_node(node->next_sibling, stream);
}
