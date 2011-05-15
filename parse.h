#ifndef PARSE_H
#define PARSE_H

#include <stdio.h>
#include "types.h"

Rule* parse_rules(FILE* file);
Node* parse_nodes(FILE* file);

#endif
