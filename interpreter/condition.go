package bonsai

type Condition struct {
	NodeType string
	ChildRule Rule
	PreventsMatch bool
	CreatesNode bool
	RemovesNode bool
	MatchesMultipleNodes bool
	Value Value
	Variable string
}
