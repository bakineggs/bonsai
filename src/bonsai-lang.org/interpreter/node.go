package main

type Node struct {
	parent *Node

	in_use bool
	children_blocking int

	children_are_ordered bool
	children []*Node

	label string

	value_type int
	integer_value int64
	decimal_value float64
	string_value string
}
