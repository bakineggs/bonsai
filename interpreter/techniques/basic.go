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
		matches, matchedConditions = b.matchesInOrder(rule, node, 0, 0)
		return
	}

	return
}

func (b *Basic) matchesInOrder(rule *bonsai.Rule, node *bonsai.Node, condition_i int, child_i int) (matches bool, matchedConditions map[*bonsai.Condition]*bonsai.Node) {
	if condition_i == len(rule.Conditions) {
		matches = !rule.MustMatchAllNodes || child_i == len(node.Children)
		if matches {
			matchedConditions = make(map[*bonsai.Condition]*bonsai.Node)
		}
		return
	}

	condition := rule.Conditions[condition_i]

	if child_i == len(node.Children) {
		if condition.PreventsMatch || condition.CreatesNode || condition.MatchesMultipleNodes {
			matches, matchedConditions = b.matchesInOrder(rule, node, condition_i + 1, child_i)
			if matches && condition.CreatesNode {
				matchedConditions[&condition] = nil // TODO: find a way to insert node that will not have a next sibling
			}
		}
		return
	}

	child := node.Children[child_i]

	if condition.PreventsMatch {
		if condition.NodeType == child.Label {
			if childMatches, _ := b.matches(&condition.ChildRule, child) ; childMatches {
				if condition.MatchesMultipleNodes {
					matches, matchedConditions = b.matchesInOrder(rule, node, condition_i + 1, child_i)
				}
				return
			}
		}

		if condition.MatchesMultipleNodes {
			matches, matchedConditions = b.matchesInOrder(rule, node, condition_i, child_i + 1)
			if matches {
				return
			}
		}

		matches, matchedConditions = b.matchesInOrder(rule, node, condition_i + 1, child_i + 1)
		return
	}

	if condition.CreatesNode {
		matches, matchedConditions = b.matchesInOrder(rule, node, condition_i + 1, child_i)
		if matches {
			matchedConditions[&condition] = child // TODO: find a way to report this such that inserting is effcient
		}
		return
	}

	if condition.NodeType == child.Label {
		childMatches, childMatchedConditions := b.matches(&condition.ChildRule, child)
		if !childMatches {
			if condition.MatchesMultipleNodes {
				matches, matchedConditions = b.matchesInOrder(rule, node, condition_i + 1, child_i)
			}
			return
		}

		if condition.MatchesMultipleNodes {
			matches, matchedConditions = b.matchesInOrder(rule, node, condition_i, child_i + 1)
			if matches {
				b.merge(&matchedConditions, &childMatchedConditions)
				if condition.RemovesNode {
					matchedConditions[&condition] = child
				}
				return
			}
		}

		matches, matchedConditions = b.matchesInOrder(rule, node, condition_i + 1, child_i + 1)
		if matches {
			b.merge(&matchedConditions, &childMatchedConditions)
			if condition.RemovesNode {
				matchedConditions[&condition] = child
			}
		}
		return
	}

	if condition.MatchesMultipleNodes {
		matches, matchedConditions = b.matchesInOrder(rule, node, condition_i + 1, child_i)
	}
	return
}

func (b *Basic) transform(rule *bonsai.Rule, matchedConditions map[*bonsai.Condition]*bonsai.Node) (children []*bonsai.Node) {
	return
}

func (b *Basic) merge(destination *map[*bonsai.Condition]*bonsai.Node, source *map[*bonsai.Condition]*bonsai.Node) {
	for condition, node := range *source {
		(*destination)[condition] = node
	}
}
