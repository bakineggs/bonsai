#ifndef BONSAI_NODE_BUILDER_H
#define BONSAI_NODE_BUILDER_H

#include "types.h"

void set_node(char* variable, Node* value);
void set_integer(char* variable, int value);
void set_decimal(char* variable, double value);
void set_string(char* variable, char* value);

Node* build_node(char* definition);

#endif
