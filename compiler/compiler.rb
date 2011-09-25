require File.dirname(__FILE__) + '/rule' unless Object.const_defined? :Rule

class Compiler
  def compile program
    rules = Parser.new.parse_rules program
  end
end
