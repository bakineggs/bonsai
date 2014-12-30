require File.dirname(__FILE__) + '/../../../parser/parser'

class Compiler
  def compile program
    compiled = File.read File.dirname(__FILE__) + '/../rules.bonsai'

    compiled += "\n^:\n  !Rules:\n  +Rules:\n"
    Parser.new.parse_program(program).each do |rule|
      compiled += compile_rule rule, 2
    end

    compiled
  end

  private

    def compile_rule rule, depth
      compiled = '  ' * depth + "Rule:\n"

      compiled += '  ' * (depth + 1) + "MustMatchAllNodes:\n" if rule.must_match_all_nodes?

      compiled += '  ' * (depth + 1) + 'Conditions:'
      compiled += ':' if rule.conditions_are_ordered?
      compiled += "\n"

      rule.conditions.each do |condition|
        compiled += compile_condition condition, depth + 2
      end

      compiled
    end

    def compile_condition condition, depth
      compiled = '  ' * depth + "Condition:\n"

      compiled += '  ' * (depth + 1) + "PreventsMatch:\n" if condition.prevents_match?
      compiled += '  ' * (depth + 1) + "CreatesNode:\n" if condition.creates_node?
      compiled += '  ' * (depth + 1) + "RemovesNode:\n" if condition.removes_node?

      compiled += '  ' * (depth + 1) + "Label: #{escaped_string condition.label}\n"

      compiled += '  ' * (depth + 1) + "MatchesMultipleNodes:\n" if condition.matches_multiple_nodes?

      compiled += '  ' * (depth + 1) + "Variable: #{escaped_string condition.variable}\n" if condition.variable
      compiled += '  ' * (depth + 1) + "Value: #{escaped_value condition.value}\n" if condition.value

      compiled += compile_rule condition.child_rule, depth + 1 if condition.child_rule

      compiled
    end

    def escaped_string contents
      "\"#{contents}\""
    end

    def escaped_value value
      if value.is_a?(Fixnum) || value.is_a?(Float)
        value
      elsif value.is_a? String
        escaped_string value
      else
        raise "Unknown value type: #{value.inspect}"
      end
    end
end
