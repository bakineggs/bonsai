package main

type Rule struct {
	top_level bool
	conditions_are_ordered bool
	must_match_all_nodes bool
	conditions []Condition
	code_segment func()
	definition string
}
