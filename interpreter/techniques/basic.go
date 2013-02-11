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
				matches, matchedConditions := b.matchesChildren(rule, node)
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

func (b *Basic) matchesChildren(rule *bonsai.Rule, node *bonsai.Node) (matches bool, matchedConditions map[*bonsai.Node][]chan *bonsai.Condition) {
	if rule.ConditionsAreOrdered != node.ChildrenAreOrdered && !rule.TopLevel {
		return
	}

	if node.ChildrenAreOrdered {
		matches, matchedConditions = b.matchesChildrenInOrder(rule, node, 0, 0)
		return
	}

	count := 0
	prevented := make(chan bool)
	for _, condition := range rule.Conditions {
		if condition.PreventsMatch {
			for _, child := range node.Children {
				go func() {
					preventing, _ := b.matchesNode(&condition, child)
					prevented <- preventing
				}()
				count++
			}
		}
	}
	for i := 0; i < count; i++ {
		if <-prevented {
			return
		}
	}

	return
}

func (b *Basic) matchesNode(condition *bonsai.Condition, node *bonsai.Node) (matches bool, matchedConditions map[*bonsai.Node][]chan *bonsai.Condition) {
	if condition.NodeType == node.Label {
		matches, matchedConditions = b.matchesChildren(&condition.ChildRule, node)
	}
	return
}

func (b *Basic) matchesChildrenInOrder(rule *bonsai.Rule, node *bonsai.Node, condition_i int, child_i int) (matches bool, matchedConditions map[*bonsai.Node][]chan *bonsai.Condition) {
	if condition_i == len(rule.Conditions) {
		matches = !rule.MustMatchAllNodes || child_i == len(node.Children)
		if matches {
			matchedConditions = make(map[*bonsai.Node][]chan *bonsai.Condition)
		}
		return
	}

	condition := &rule.Conditions[condition_i]

	if child_i == len(node.Children) {
		if condition.PreventsMatch || condition.CreatesNode || condition.MatchesMultipleNodes {
			matches, matchedConditions = b.matchesChildrenInOrder(rule, node, condition_i + 1, child_i)
			if matches && condition.CreatesNode {
				b.storeMatchedCondition(&matchedConditions, node, child_i, condition, rule)
			}
		}
		return
	}

	child := node.Children[child_i]

	if condition.PreventsMatch {
		if prevents, _ := b.matchesNode(condition, child) ; prevents {
			if condition.MatchesMultipleNodes {
				matches, matchedConditions = b.matchesChildrenInOrder(rule, node, condition_i + 1, child_i)
			}
			return
		}

		if condition.MatchesMultipleNodes {
			matches, matchedConditions = b.matchesChildrenInOrder(rule, node, condition_i, child_i + 1)
			if matches {
				return
			}
		}

		matches, matchedConditions = b.matchesChildrenInOrder(rule, node, condition_i + 1, child_i + 1)
		return
	}

	if condition.CreatesNode {
		matches, matchedConditions = b.matchesChildrenInOrder(rule, node, condition_i + 1, child_i)
		if matches {
			b.storeMatchedCondition(&matchedConditions, node, child_i, condition, rule)
		}
		return
	}

	if nodeMatches, childMatchedConditions := b.matchesNode(condition, child) ; nodeMatches {
		if condition.MatchesMultipleNodes {
			matches, matchedConditions = b.matchesChildrenInOrder(rule, node, condition_i, child_i + 1)
			if matches {
				b.merge(&matchedConditions, &childMatchedConditions)
				if condition.RemovesNode {
					b.storeMatchedCondition(&matchedConditions, node, child_i, condition, rule)
				}
				return
			}
		}

		matches, matchedConditions = b.matchesChildrenInOrder(rule, node, condition_i + 1, child_i + 1)
		if matches {
			b.merge(&matchedConditions, &childMatchedConditions)
			if condition.RemovesNode {
				b.storeMatchedCondition(&matchedConditions, node, child_i, condition, rule)
			}
		}
	}

	if condition.MatchesMultipleNodes {
		matches, matchedConditions = b.matchesChildrenInOrder(rule, node, condition_i + 1, child_i)
	}
	return
}

func (b *Basic) transform(rule *bonsai.Rule, matchedConditions map[*bonsai.Node][]chan *bonsai.Condition) (children []*bonsai.Node) {
	return
}

func (b *Basic) storeMatchedCondition(matchedConditions *map[*bonsai.Node][]chan *bonsai.Condition, parent *bonsai.Node, child_i int, condition *bonsai.Condition, rule *bonsai.Rule) {
	if (*matchedConditions)[parent] == nil {
		(*matchedConditions)[parent] = make([]chan *bonsai.Condition, len(parent.Children) + 1)
	}
	if (*matchedConditions)[parent][child_i] == nil {
		(*matchedConditions)[parent][child_i] = make(chan *bonsai.Condition, len(rule.Conditions))
	}
	(*matchedConditions)[parent][child_i] <- condition
}

func (b *Basic) merge(destination *map[*bonsai.Node][]chan *bonsai.Condition, source *map[*bonsai.Node][]chan *bonsai.Condition) {
	for node, chans := range *source {
		(*destination)[node] = chans
	}
}
