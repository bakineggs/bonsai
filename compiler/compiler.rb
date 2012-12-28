require File.dirname(__FILE__) + '/parser'

class Compiler
  def compile program
    rules = Parser.new.parse_program program

    <<-EOS
      package main

      import "./bonsai/interpreter"

      func CompiledRules() []*bonsai.Rule {
        return []*bonsai.Rule{#{
          rules.map do |rule|
            "&#{compile_rule rule}"
          end.join ','
        }}
      }
    EOS
  end

  private

    def compile_rule rule
      compiled = ""
      compiled += rule_definition_comment rule if rule.top_level?
      compiled += 'bonsai.Rule{'
      compiled += "TopLevel: #{rule.top_level?},"
      compiled += "ConditionsAreOrdered: #{rule.conditions_are_ordered?},"
      compiled += "MustMatchAllNodes: #{rule.must_match_all_nodes?},"
      compiled += "Conditions: []bonsai.Condition{#{rule.conditions.map {|c| compile_condition c}.join ','}},"
      compiled += "CodeSegment: func() {},"
      compiled += "Definition: #{escaped_string rule.definition.join '\n'}"
      compiled + '}'
    end

    def compile_condition condition
      compiled = 'bonsai.Condition{'
      compiled += "NodeType: #{escaped_string condition.node_type},"
      compiled += "ChildRule: #{compile_rule condition.child_rule},"
      compiled += "PreventsMatch: #{condition.prevents_match?},"
      compiled += "CreatesNode: #{condition.creates_node?},"
      compiled += "RemovesNode: #{condition.removes_node?},"
      compiled += "MatchesMultipleNodes: #{condition.matches_multiple_nodes?},"
      compiled += "Value: #{escaped_value condition.value},"
      compiled += "Variable: #{escaped_string condition.variable}"
      compiled + '}'
    end

    def rule_definition_comment rule
      comment = "\n/*\n"
      rule.definition.each do |line|
        comment += "  #{line} (line #{line.line_number})\n"
      end
      comment + "*/\n"
    end

    def escaped_string contents
      "\"#{contents.to_s.gsub '"', '\"'}\""
    end

    def escaped_value value
      if value.is_a? Fixnum
        "bonsai.IntegerValue(#{value})"
      elsif value.is_a? Float
        "bonsai.DecimalValue(#{value})"
      elsif value.is_a? String
        "bonsai.StringValue(#{escaped_string value})"
      elsif value.nil?
        'nil'
      else
        raise "Unknown value type: #{value.inspect}"
      end
    end
end
