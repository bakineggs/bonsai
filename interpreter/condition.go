package bonsai

type Condition struct {
	node_type string
	child_rule Rule
	prevents_match bool
	creates_node bool
	removes_node bool
	matches_multiple_nodes bool
	value Value
	variable string
}
