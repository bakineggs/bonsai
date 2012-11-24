package main

import "fmt"
import "time"

type result struct {
	transformation *Node
	newly_matching []*Rule
	newly_not_matching []*Rule
	new_techniques []*Technique
	continue_using bool
}

type Technique interface {
	apply(
		rules []*Rule,
		node *Node,
		matching map[*Rule]bool,
		not_matching map[*Rule]bool) (result)
}

func apply_technique(technique Technique, rules []Rule, node *Node, results chan result) {
	results <- result{}
}

func apply(techniques []Technique, rules []Rule, queue *Queue, node *Node) {
	results := make(chan result)
	transformed := false

	for _, technique := range techniques {
		go apply_technique(technique, rules, node, results)
	}
	for _, technique := range techniques {
		r := <-results
		if (!transformed && r.transformation != nil) {
			//node = r.transformation
			transformed = true
		}
		if (r.continue_using) {
			fmt.Println(technique)
		} else {
		}
	}

	node.in_use = false
	if (transformed) {
		queue.insert(node)
	}
}

func main() {
	rules := []Rule{}
	techniques := []Technique{}

	root := Node{}
	queue := Queue{}
	queue.lock = make(semaphore, 1)
	queue.insert(&root)

	for root.in_use {
		time.Sleep(1) // otherwise we don't halt
		node := queue.pop()
		for node != nil {
			if (node.children_blocking > 0) {
				queue.insert(node);
			} else {
				go apply(techniques, rules, &queue, node);
			}
			node = queue.pop()
		}
	}


	if root.parent == nil {
		fmt.Println("nil")
	} else {
		fmt.Println("not nil")
	}
}
