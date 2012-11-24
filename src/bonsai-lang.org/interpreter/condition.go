package main

type Condition struct {
	node_type string
	child_rule Rule
	prevents_match bool
	creates_node bool
	removes_node bool
	matches_multiple_nodes bool
	integer_value int64
	decimal_value float64
	string_value string
	variable string
}
