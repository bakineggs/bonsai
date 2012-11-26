package main

func main() {
	rules := []Rule{}
	techniques := []Technique{}

	for _, technique := range techniques {
		technique.Learn(rules)
	}

	interpreter := Interpreter{techniques: techniques}
	interpreter.Interpret()
}
