require File.dirname(__FILE__) + '/parser'

class Compiler
  def compile program
    rules = Parser.new.parse_rules program

    # Pseudo-code for generated interpreter:
    #
    # Nodes = [^], a poset in which all nodes come before their ancestors
    #
    # until Nodes is empty
    #   Node = shift Nodes
    #
    #   if a rule can be, and is, applied to Node
    #     add Node and its ancestors to Nodes
    #   else
    #     add Node's children to Nodes

    "int main() { return 0; }"
  end
end
