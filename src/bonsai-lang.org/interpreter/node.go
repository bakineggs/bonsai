package main

type Node struct {
	lock chan empty

	label string

	parent *Node
	children []*Node
	children_are_ordered bool

	value_type int
	integer_value int64
	decimal_value float64
	string_value string
}
