#ifndef TYPES_H
#define TYPES_H

typedef enum BOOL { false, true } bool;

typedef struct Rule {
  struct Rule* next; // instead of having a RuleSet or whatnot

  struct Condition* conditions;
} Rule;

typedef struct Condition {
  struct Condition* next; // instead of having of ConditionList or whatnot

  char* node_type;

  bool creates_node;
  bool removes_node;

  bool matches_node;
  bool excludes_node;

  bool exact;
  bool ordered;
  bool multiple;

  char* variable;

  struct Condition* parent;
  struct Condition* children;

  // instead of checking for these all the time
  bool ancestor_creates_node;
  bool ancestor_removes_node;
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

#endif
