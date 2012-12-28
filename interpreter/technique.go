package bonsai

type Technique interface {
	Learn(rules []*Rule)
	Transform(node *Node, matched *map[*Rule]bool, mismatched *map[*Rule]bool) (children []*Node, techniques []Technique, continueUsing bool)
}
