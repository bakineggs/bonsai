package techniques

import "../"

type empty struct {}

type Basic struct {
	rules []*bonsai.Rule
}

func (b *Basic) Learn(rules []*bonsai.Rule) {
	b.rules = rules
}

func (b *Basic) Transform(node *bonsai.Node, matched *map[*bonsai.Rule]bool, mismatched *map[*bonsai.Rule]bool) (children []*bonsai.Node, techniques []bonsai.Technique, continueUsing bool) {
	continueUsing = true

	transformations := make(chan []*bonsai.Node, 1)
	notTransformed := make(chan empty)

	for _, rule := range b.rules {
		go func() {
			if (*matched)[rule] || (*mismatched)[rule] {
				notTransformed <- empty{}
			} else {
				matches, matchedConditions := b.matches(rule, node)
				if matches {
					(*matched)[rule] = true
					transformation := b.transform(rule, matchedConditions)
					if transformation != nil {
						transformations <- transformation
					} else {
						notTransformed <- empty{}
					}
				} else {
					(*mismatched)[rule] = true
					notTransformed <- empty{}
				}
			}
		}()
	}

	for _ = range b.rules {
		select {
		case transformation := <-transformations:
			children = transformation
			return
		case <-notTransformed:
		}
	}

	return
}

func (b *Basic) matches(rule *bonsai.Rule, node *bonsai.Node) (matches bool, matchedConditions map[*bonsai.Condition]*bonsai.Node) {
	if rule.ConditionsAreOrdered != node.ChildrenAreOrdered && !rule.TopLevel {
		return
	}

	if node.ChildrenAreOrdered {
		matches, matchedConditions = b.matchesInOrder(rule, node)
		return
	}

	return
}

func (b *Basic) matchesInOrder(rule *bonsai.Rule, node *bonsai.Node) (matches bool, matchedConditions map[*bonsai.Condition]*bonsai.Node) {
	return
}

func (b *Basic) transform(rule *bonsai.Rule, matchedConditions map[*bonsai.Condition]*bonsai.Node) (children []*bonsai.Node) {
	return
}
