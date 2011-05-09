Rule* parse_rules(FILE* file);
Rule* parse_rule(FILE* file);
Condition* parse_conditions(FILE* file);

char VALID_NODE_NAME_CHARS[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 ";
