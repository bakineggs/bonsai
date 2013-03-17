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
				if matches && b.matchesVariables(matchedConditions) {
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

	matchedConditions = make(map[*bonsai.Node][]chan *bonsai.Condition)

	preventedCount := 0
	prevented := make(chan bool)

	singlyMatchedConditions := make(map[*bonsai.Node]chan *bonsai.Condition)
	singlyMatchedNodes := make(map[*bonsai.Condition]chan *bonsai.Node)
	singlyMatchedNodeChildConditions := make(map[*bonsai.Node]map[*bonsai.Condition]*map[*bonsai.Node][]chan *bonsai.Condition)

	for _, child := range node.Children {
		singlyMatchedConditions[child] = make(chan *bonsai.Condition, len(rule.Conditions))
		singlyMatchedNodeChildConditions[child] = make(map[*bonsai.Condition]*map[*bonsai.Node][]chan *bonsai.Condition)
	}

	multiplyMatchedConditions := make([]*bonsai.Condition, 0, len(rule.Conditions))

	for index := range node.Children {
		b.initMatchedCondition(&matchedConditions, node, index, rule)
	}

	for _, condition := range rule.Conditions {
		if condition.PreventsMatch {
			for index, child := range node.Children {
				go func() {
					preventing, childMatchedConditions := b.matchesNode(&condition, child)
					if preventing {
						b.merge(&matchedConditions, &childMatchedConditions)
						if condition.Variable != "" {
							b.storeMatchedCondition(&matchedConditions, node, index, &condition, rule)
							preventing = false
						}
					}
					prevented <- preventing
				}()
				preventedCount++
			}
		} else if !condition.CreatesNode && !condition.MatchesMultipleNodes {
			singlyMatchedNodes[&condition] = make(chan *bonsai.Node, len(node.Children))
			preventedCount++
			go func() {
				childrenDone := make(chan empty)
				for _, child := range node.Children {
					go func() {
						if matchesNode, childMatchedConditions := b.matchesNode(&condition, child) ; matchesNode {
							singlyMatchedNodeChildConditions[child][&condition] = &childMatchedConditions;
							singlyMatchedConditions[child] <- &condition
							singlyMatchedNodes[&condition] <- node
						}
						childrenDone <- empty{}
					}()
				}
				for _ = range node.Children { <-childrenDone }
				select {
				case matched := <-singlyMatchedNodes[&condition]:
					singlyMatchedNodes[&condition] <- matched
					prevented <- false
				default:
					prevented <- true
				}
			}()
		} else if condition.MatchesMultipleNodes {
			multiplyMatchedConditions[len(multiplyMatchedConditions)] = &condition
		}
	}
	for i := 0; i < preventedCount; i++ {
		if <-prevented {
			matchedConditions = nil
			return
		}
	}

	singlyMatchedConditionLists := make(map[*bonsai.Node][]*bonsai.Condition)
	for matchedNode, conditionChan := range singlyMatchedConditions {
		select {
		case condition := <-conditionChan:
			conditionChan <- condition

			singlyMatchedConditionLists[matchedNode] = make([]*bonsai.Condition, 0, len(rule.Conditions))
			for condition = range conditionChan {
				singlyMatchedConditionLists[matchedNode][len(singlyMatchedConditionLists[matchedNode])] = condition
			}
		default:
		}
	}

	pairings := b.findPairings(singlyMatchedConditionLists, make(map[*bonsai.Condition]bool))
	if pairings == nil {
		matchedConditions = nil
		return
	}

	childrenDone := make(chan empty, len(node.Children))
	for index, child := range node.Children {
		go func() {
			if pairings[child] != nil {
				if pairings[child].RemovesNode || pairings[child].Variable != "" {
					b.storeMatchedCondition(&matchedConditions, node, index, pairings[child], rule)
				}
				b.merge(&matchedConditions, singlyMatchedNodeChildConditions[child][pairings[child]])
			} else {
				multiplyMatchedNodeChildConditions := make(chan map[*bonsai.Node][]chan *bonsai.Condition, len(multiplyMatchedConditions))
				conditionsDone := make(chan empty, len(multiplyMatchedConditions))
				for _, condition := range multiplyMatchedConditions {
					go func() {
						if childMatches, childMatchedConditions := b.matchesNode(condition, child) ; childMatches {
							multiplyMatchedNodeChildConditions <- childMatchedConditions
						} else {
							conditionsDone <- empty{}
						}
					}()
				}
				for _, condition := range multiplyMatchedConditions {
					select {
					case childMatchedConditions := <-multiplyMatchedNodeChildConditions:
						if condition.RemovesNode || condition.Variable != "" {
							b.storeMatchedCondition(&childMatchedConditions, node, index, condition, rule)
						}
						b.merge(&matchedConditions, &childMatchedConditions)
						break
					case <-conditionsDone:
					}
				}
			}
			childrenDone <- empty{}
		}()
	}
	for _ = range node.Children {
		<-childrenDone
	}

	// TODO: include creating conditions
	// TODO: don't match if rule.MustMatchAllNodes and we don't match all nodes

	return
}

func (b *Basic) findPairings(matchedConditions map[*bonsai.Node][]*bonsai.Condition, ignored map[*bonsai.Condition]bool) (pairings map[*bonsai.Node]*bonsai.Condition) {
	pairings = make(map[*bonsai.Node]*bonsai.Condition)
	for node, conditions := range matchedConditions {
		matched := make([]*bonsai.Condition, len(conditions))
		for _, condition := range conditions {
			if !ignored[condition] {
				matched[len(matched)] = condition
			}
		}

		if len(matched) > 1 {
			delete(matchedConditions, node)
			for _, condition := range matched {
				ignored[condition] = true
				if pairings = b.findPairings(matchedConditions, ignored) ; pairings != nil {
					pairings[node] = condition
					return
				}
				ignored[condition] = false
			}
			return
		} else if len(matched) == 1 {
			pairings[node] = matched[0]
		}
	}
	return
}

func (b *Basic) matchesNode(condition *bonsai.Condition, node *bonsai.Node) (matches bool, matchedConditions map[*bonsai.Node][]chan *bonsai.Condition) {
	// TODO: document that ** means to matched either ordered conditions or unordered conditions
	//				- can not have child conditions
	//				- can not require matching all nodes
	//				- useful for **:* to match any number of any kind of node
	//				- allows *: and *:: to be used for matching only ordered or only unordered
	if condition.NodeType == "**" {
		matches, matchedConditions = true, make(map[*bonsai.Node][]chan *bonsai.Condition)
	} else if condition.NodeType == node.Label || condition.NodeType == "*" {
		matches, matchedConditions = b.matchesChildren(&condition.ChildRule, node)
	}

	// TODO: compare values

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

func (b *Basic) matchesVariables(matchedConditions map[*bonsai.Node][]chan *bonsai.Condition) (matches bool) {
	// TODO: make sure variables match
	return
}

func (b *Basic) transform(rule *bonsai.Rule, matchedConditions map[*bonsai.Node][]chan *bonsai.Condition) (children []*bonsai.Node) {
	// TODO: transform node based on matched conditions
	return
}

func (b *Basic) initMatchedCondition(matchedConditions *map[*bonsai.Node][]chan *bonsai.Condition, parent *bonsai.Node, child_i int, rule *bonsai.Rule) {
	if (*matchedConditions)[parent] == nil {
		(*matchedConditions)[parent] = make([]chan *bonsai.Condition, len(parent.Children) + 1)
	}
	if (*matchedConditions)[parent][child_i] == nil {
		(*matchedConditions)[parent][child_i] = make(chan *bonsai.Condition, len(rule.Conditions))
	}
}

func (b *Basic) storeMatchedCondition(matchedConditions *map[*bonsai.Node][]chan *bonsai.Condition, parent *bonsai.Node, child_i int, condition *bonsai.Condition, rule *bonsai.Rule) {
	b.initMatchedCondition(matchedConditions, parent, child_i, rule)
	(*matchedConditions)[parent][child_i] <- condition
}

func (b *Basic) merge(destination *map[*bonsai.Node][]chan *bonsai.Condition, source *map[*bonsai.Node][]chan *bonsai.Condition) {
	for node, chans := range *source {
		(*destination)[node] = chans
	}
}
