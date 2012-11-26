package main

type Interpreter struct {
	techniques []Technique
	techniquesLock chan empty
	queue chan *Node
}

func (i *Interpreter) Interpret() {
	i.queue = make(chan *Node, 1048576)

	root := &Node{lock: make(chan empty, 1), label: "^", children: make([]*Node, 0)}
	i.enqueue(root)

	done := make(chan empty, 1)
	go i.processQueue(done)

	<-root.lock
	done <- empty{}
}

func (i *Interpreter) enqueue(node *Node) {
	for _, child := range node.children {
		i.enqueue(child)
	}
	i.queue <- node
}

func (i *Interpreter) processQueue(done chan empty) {
	for {
		select {
		case <-done:
			return
		case node := <-i.queue:
			go i.transform(node)
		}
	}
}

func (i *Interpreter) transform(node *Node) {
	for _, child := range node.children {
		<-child.lock
	}

	done := make(chan empty, 1)
	//techniquesDone := make(chan empty, len(i.techniques))
	techniquesDone := make(chan int, len(i.techniques))
	go func() {
		for index := range i.techniques {
			//<-techniquesDone
			techniquesDone <- index // TODO: can we iterate over a range w/o using the var?
		}
		done <- empty{}
	}()

	transformations := make(chan []*Node)
	matched := make(map[*Rule]bool)
	mismatched := make(map[*Rule]bool)

	for _, technique := range i.techniques {
		go func() {
			children, techniques, continueUsing := technique.Transform(node, &matched, &mismatched)

			if children == nil {
				//techniquesDone <- empty{}
				<-techniquesDone
			} else {
				transformations <- children
			}

			if techniques != nil {
				i.learnTechniques(techniques)
			}

			if !continueUsing {
				i.unlearnTechnique(&technique)
			}
		}()
	}

	select {
	case children := <-transformations:
		node.children = children
		i.enqueue(node)
	case <-done:
		node.lock <- empty{}
	}
}

func (i *Interpreter) learnTechniques(techniques []Technique) {
	i.techniquesLock <- empty{}
	i.techniques = append(i.techniques, techniques...)
	<-i.techniquesLock
}

func (i *Interpreter) unlearnTechnique(technique *Technique) {
	i.techniquesLock <- empty{}
	for index, technique := range i.techniques {
		if i.techniques[index] == technique {
			i.techniques[index] = i.techniques[len(i.techniques) - 1]
			i.techniques = i.techniques[:len(i.techniques) - 1]
			return
		}
	}
	<-i.techniquesLock
}
