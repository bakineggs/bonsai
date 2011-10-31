require File.dirname(__FILE__) + '/parser'

class Compiler
  def compile program
    rules = Parser.new.parse_rules program

    <<-EOS
      #include <stdlib.h>
      #include <stdio.h>
      #include <string.h>

      #{File.read File.dirname(__FILE__) + '/../types.h'}

      #{File.read File.dirname(__FILE__) + '/runtime.c'}

      #{apply_rules rules}
    EOS
  end

  private
    def apply_rules rules
      apply_rules = ""

      rules.each_with_index do |rule, index|
        apply_rules += <<-EOS
          bool apply_rule_#{index}(Node* node) {
            return false;
          }
        EOS
      end

      apply_rules += <<-EOS
        bool apply_rules(Node* node) {
      EOS

      apply_rules += (0...rules.length).map do |i|
        <<-EOS
          if (apply_rule_#{i}(node))
            return true;
        EOS
      end.join ' else '

      apply_rules + <<-EOS
          return false;
        }
      EOS
    end
end
