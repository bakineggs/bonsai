require File.dirname(__FILE__) + '/parser'

class Compiler
  def compile program
    rules = Parser.new.parse_rules program
  end
end
