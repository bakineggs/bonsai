Rule* parse_rules(FILE* file);
Rule* parse_rule(FILE* file);
Condition* parse_conditions(FILE* file);

Node* parse_nodes(FILE* file);

void parse_error(char* message, char* line);

char VALID_NODE_NAME_CHARS[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 ";
