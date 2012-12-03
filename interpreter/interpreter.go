package bonsai

import "net"
import "net/rpc"

type Interpreter struct {
	peers chan *rpc.Client
	Techniques []Technique
	techniquesLock chan empty
	queue chan *Node
}

func (i *Interpreter) Interpret(port string, root *Node) error {
	i.queue = make(chan *Node)

	if port != "" {
		listener, err := net.Listen("tcp", port)
		if err != nil {
			panic(err)
		}

		rpc.Register(i)
		go rpc.Accept(listener)
	}

	root.lock = make(chan empty, 1)
	root.label = "^"
	root.children = make([]*Node, 0)
	go i.enqueue(root)

	sendToPeer := make(chan empty)
	go i.processQueue(sendToPeer)
	go i.monitorResources(sendToPeer)

	<-root.lock
	return nil
}

func (i *Interpreter) AddPeer(address string, reply *bool) error {
	peer, err := rpc.Dial("tcp", address)
	if err != nil {
		panic(err)
	}
	i.peers <- peer
	return nil
}

func (i *Interpreter) Enqueue(node *Node, transformation *Node) error {
	go i.enqueue(node)
	<-node.lock
	transformation = node
	return nil
}

func (i *Interpreter) sendToPeer(node *Node) {
	select {
	case peer := <-i.peers:
		i.peers <- peer

		var transformation *Node
		err := peer.Call("Interpreter.Enqueue", node, transformation)
		if err != nil {
			panic(err)
		}

		node.children = transformation.children
		i.enqueue(node)

	default:
		i.transform(node)
	}
}

func (i *Interpreter) enqueue(node *Node) {
	for _, child := range node.children {
		go i.enqueue(child)
	}
	i.queue <- node
}

func (i *Interpreter) processQueue(sendToPeer chan empty) {
	for {
		node := <-i.queue
		go func() {
			for _, child := range node.children {
				<-child.lock
			}
			select {
			case <-sendToPeer:
				i.sendToPeer(node)
			default:
				i.transform(node)
			}
		}()
	}
}

// TODO: continuously monitor resources and use sendToPeer to say how many nodes to send away
func (i *Interpreter) monitorResources(sendToPeer chan empty) {
	sendToPeer <- empty{}
}

func (i *Interpreter) transform(node *Node) {
	done := make(chan empty, 1)
	//techniquesDone := make(chan empty, len(i.techniques))
	techniquesDone := make(chan int, len(i.Techniques))
	go func() {
		for index := range i.Techniques {
			//<-techniquesDone
			techniquesDone <- index // TODO: can we iterate over a range w/o using the var?
		}
		done <- empty{}
	}()

	transformations := make(chan []*Node)
	matched := make(map[*Rule]bool)
	mismatched := make(map[*Rule]bool)

	for _, technique := range i.Techniques {
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

// TODO: this needs to work with rpc peers
func (i *Interpreter) learnTechniques(techniques []Technique) {
	i.techniquesLock <- empty{}
	i.Techniques = append(i.Techniques, techniques...)
	<-i.techniquesLock
}

func (i *Interpreter) unlearnTechnique(technique *Technique) {
	i.techniquesLock <- empty{}
	for index, technique := range i.Techniques {
		if i.Techniques[index] == technique {
			i.Techniques[index] = i.Techniques[len(i.Techniques) - 1]
			i.Techniques = i.Techniques[:len(i.Techniques) - 1]
			return
		}
	}
	<-i.techniquesLock
}
