#ifndef OKK_TYPES_H
#define OKK_TYPES_H

#ifdef __cplusplus
  enum value { none, integer, decimal, string };
#else
  typedef enum { false = 0, true = 1 } bool;
  typedef enum { none, integer, decimal, string } value;
#endif

#ifndef NULL
  #define NULL 0
#endif

typedef struct Node {
  struct Node* parent;
  struct Node* next_sibling;
  struct Node* previous_sibling;

  bool children_are_ordered;
  struct Node* children;

  struct Node* next_in_poset;

  char* type;

  value value_type;
  long int integer_value;
  double decimal_value;
  char* string_value;
} Node;

#endif
