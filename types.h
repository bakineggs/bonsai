#ifndef TYPES_H
#define TYPES_H

#ifndef __cplusplus
typedef enum BOOL { false, true } bool;
#endif

typedef struct Rule {
  struct Rule* next; // instead of having a RuleSet or whatnot
  struct Condition* parent;

  bool exact;

  bool ordered;
  struct Condition* ordered_conditions;

  struct Condition* preventing;
  struct Condition* matching_single;
  struct Condition* matching_multiple;
  struct Condition* creating;
} Rule;

typedef struct Condition {
  struct Condition* next; // instead of having of ConditionList or whatnot

  char* node_type;
  char* variable;

  bool creates_node;
  bool removes_node;

  struct Rule* rule;
  struct Rule* children;
} Condition;

typedef struct Node {
  // instead of having a NodeSet or whatnot
  struct Node* previous;
  struct Node* next;

  char* type;
  bool ordered;

  long int* integer_value;
  double* decimal_value;
  char* string_value;

  struct Node* parent;
  struct Node* children;
} Node;

typedef struct Match {
  struct Match* other; // alternative set of matches

  struct Match* next; // next match in the set

  struct Condition* condition;
  struct Node* node;
  struct Node* parent;
} Match;

#endif
