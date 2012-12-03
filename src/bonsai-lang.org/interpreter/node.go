package main

type Node struct {
	lock chan empty

	label string

	parent *Node
	children []*Node
	children_are_ordered bool

	value Value
}

func (n *Node) ToString() string {
	return n.toString(0)
}

func (n *Node) toString(depth int) (str string) {
	for i := 0; i < depth; i++ {
		str += "  "
	}
	str += n.label + ":"

	if (n.children_are_ordered) {
		str += ":"
	} else if (n.value != nil) {
		str += " " + n.value.ToString()
	}
	str += "\n"

	for _, child := range n.children {
		str += child.toString(depth + 1)
	}
	return
}
