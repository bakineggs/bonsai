#ifndef PARSE_H
#define PARSE_H

#include <stdio.h>
#include "types.h"

Rule* parse_rules(FILE* file);
Node* parse_nodes(FILE* file);
void parsing_done(); // frees memory that is needed to parse more

#endif
