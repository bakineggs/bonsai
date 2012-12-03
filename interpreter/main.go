package main

import "fmt"
import "os"

func main() {
	rules := []Rule{}
	techniques := []Technique{}

	for _, technique := range techniques {
		technique.Learn(rules)
	}

	interpreter := Interpreter{techniques: techniques}
	root := interpreter.interpret()

	fmt.Fprint(os.Stderr, root.ToString())
	os.Exit(1)
}
