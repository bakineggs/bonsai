#include <stdio.h>

#include "print.h"

void preceding_spaces(Node* node) {
  while (node = node->parent)
    printf("  ");
}

void print_node(Node* node) {
  if (!node)
    return;

  preceding_spaces(node);
  printf("%s:", node->type);

  if (node->ordered)
    printf(":");
  else if (node->integer_value)
    printf(" %li", *node->integer_value);
  else if (node->decimal_value)
    printf(" %f", *node->decimal_value);
  else if (node->string_value)
    printf(" %s", node->string_value);

  printf("\n");

  print_node(node->children);
  print_node(node->next);
}
