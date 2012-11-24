package main

type empty struct {}
type semaphore chan empty

type Queue struct {
	lock semaphore
	nodes []*Node
	head int
	tail int
}

func (q *Queue) insert(n *Node) {
	n.in_use = true
	q.lock <- empty{}

	if q.nodes == nil {
		q.nodes = make([]*Node, 64)
	} else if (q.tail + 1) % cap(q.nodes) == q.head {
		nodes := make([]*Node, cap(q.nodes) * 2)
		if (q.head < q.tail) {
			copy(nodes[q.head:q.tail], q.nodes[q.head:q.tail])
		} else {
			copy(nodes[q.head:cap(q.nodes)], q.nodes[q.head:])
			copy(nodes[cap(q.nodes):cap(q.nodes)+q.tail], q.nodes[:q.tail])
			q.tail += cap(q.nodes)
		}
		q.nodes = nodes
	}

	n.children_blocking = len(n.children)

	q.nodes[q.tail] = n
	q.tail = (q.tail + 1) % cap(q.nodes)

	<-q.lock

	for _, c := range n.children {
		go q.insert(c)
	}
}

func (q *Queue) pop() *Node {
	q.lock <- empty{}

	if (q.head == q.tail) {
		<-q.lock
		return nil
	}

	n := q.nodes[q.head]
	q.head = (q.head + 1) % cap(q.nodes)

	<-q.lock
	return n
}

func (q *Queue) empty() bool {
	return q.head == q.tail
}
