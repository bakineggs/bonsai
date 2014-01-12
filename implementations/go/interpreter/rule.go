package bonsai

type Rule struct {
	TopLevel bool
	ConditionsAreOrdered bool
	MustMatchAllNodes bool
	Conditions []Condition
	CodeSegment func()
	Definition string
}
