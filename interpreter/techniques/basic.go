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
	not_transformed := make(chan empty)

	for _, rule := range b.rules {
		go func() {
			if (*matched)[rule] || (*mismatched)[rule] {
			} else if b.matches(rule, node) {
				(*matched)[rule] = true
			} else {
				(*mismatched)[rule] = true
			}

			if (*matched)[rule] {
				transformation := b.transform(rule, node)
				if transformation != nil {
					transformations <- transformation
				} else {
					not_transformed <- empty{}
				}
			} else {
				not_transformed <- empty{}
			}
		}()
	}

	for _ = range b.rules {
		select {
		case transformation := <-transformations:
			children = transformation
			return
		case <-not_transformed:
		}
	}

	return
}

func (b *Basic) matches(rule *bonsai.Rule, node *bonsai.Node) (matches bool) {
	return
}

func (b *Basic) transform(rule *bonsai.Rule, node *bonsai.Node) (children []*bonsai.Node) {
	return
}
