require 'spec'
require File.dirname(__FILE__) + '/../../compiler/parser'

describe Parser do
  def parse type, body, depth = 0
    body.gsub! /^ {#{depth * 2}}/, ''
    body = body.split "\n" if [:rule, :conditions].include?(type)
    args = [:"parse_#{type}", body]
    args += [0, {:top_level => true}] if type == :rule
    Parser.new.send *args
  end

  describe '#parse_program' do
    describe 'header' do
      it 'does not include a header without one' do
        parse(:program, "")[:header].should == ""
      end

      it 'includes a header' do
        program = parse :program, <<-EOS, 5
          Foo:
          %{
          omg;

          hi;
          %}

          Bar:
        EOS
        program[:header].should == <<-EOS.gsub(/ {10}/, '').gsub("hi;\n", 'hi;')
          omg;

          hi;
        EOS
        program[:rules].length.should == 2
      end
    end

    describe 'syntax errors' do
      it 'includes the line of any syntax error' do
        lambda {
          parse :program, <<-EOS, 6
            Foo:
              Bar:
                :Baz
              Qux:
          EOS
        }.should raise_error(Parser::Error) { |error|
          error.line.line_number.should == 3
          error.line.should == "    :Baz"
        }
      end

      it 'requires the first condition to be on the top level' do
        lambda {
          parse :program, <<-EOS, 6
              Foo:
          EOS
        }.should raise_error(Parser::Error) { |error|
          error.line.line_number.should == 1
          error.line.should == "  Foo:"
          error.message.should == "The first condition of a rule must be at the top level"
        }
      end

      it 'rejects conditions in between levels' do
        lambda {
          parse :program, <<-EOS, 6
            Foo:
             Bar:
          EOS
        }.should raise_error(Parser::Error) { |error|
          error.line.line_number.should == 2
          error.line.should == " Bar:"
          error.message.should == "Conditions can not be in between levels"
        }
      end

      it 'rejects conditions more than one level below their parents' do
        lambda {
          parse :program, <<-EOS, 6
            Foo:
                Bar:
          EOS
        }.should raise_error(Parser::Error) { |error|
          error.line.line_number.should == 2
          error.line.should == "    Bar:"
          error.message.should == "Conditions must be at most 1 level below their parents"
        }
      end

      it 'errors out with an invalid header' do
        lambda {
          parse :program, <<-EOS, 6
            %}
            %{
          EOS
        }.should raise_error(Parser::Error) { |error|
          error.line.line_number.should == 1
          error.line.should == "%}"
          error.message.should == "Expected start of header to come before end of header"
        }

        lambda {
          parse :program, <<-EOS, 6
            %}
          EOS
        }.should raise_error(Parser::Error) { |error|
          error.line.line_number.should == 1
          error.line.should == "%}"
          error.message.should == "Expected start of header to come before end of header"
        }
      end

      it 'does not allow nodes with values to have children' do
        lambda {
          parse :program, <<-EOS, 6
            Foo: 16
              Bar:
          EOS
        }.should raise_error(Parser::Error) { |error|
          error.line.line_number.should == 2
          error.line.should == '  Bar:'
          error.message.should == 'Nodes with values can not have children'
        }
      end
    end

    it 'returns an empty list of rules with an empty program' do
      parse(:program, "")[:rules].should be_empty
    end

    it 'ignores empty lines' do
      parse(:program, <<-EOS, 4)[:rules].should be_empty

      EOS
    end

    it 'ignores empty lines between rules' do
      parse(:program, <<-EOS, 4)[:rules].length.should == 2

        Foo:


        Bar:

      EOS
    end

    it 'ignores comments' do
      parse(:program, <<-EOS, 4)[:rules].length.should == 2
        Foo: # comment

        # another comment

        # yet another comment
        Bar:
      EOS
    end

    it 'treats a whole-line comment as a rule separator' do
      parse(:program, <<-EOS, 4)[:rules].length.should == 2
        Foo:
        # comment
        Bar:
      EOS
    end

    it 'considers the top level rule to have unordered children' do
      parse(:program, 'Foo:')[:rules].first.conditions_are_ordered?.should be_false
      parse(:program, 'Foo::')[:rules].first.conditions_are_ordered?.should be_false
    end

    it 'considers the top level rule to not require all nodes to be matched' do
      parse(:program, 'Foo:')[:rules].first.must_match_all_nodes?.should be_false
      parse(:program, 'Foo:=')[:rules].first.must_match_all_nodes?.should be_false
    end

    it 'includes the definitions of the rules' do
      rules = parse(:program, <<-EOS, 4)[:rules]
        Foo:
          Bar:

        Baz:
      EOS
      rules[0].definition.should == ['Foo:', '  Bar:']
      rules[0].definition[0].line_number.should == 1
      rules[0].definition[1].line_number.should == 2

      rules[1].definition.should == ['Baz:']
      rules[1].definition[0].line_number.should == 4

      rules[0].conditions[0].child_rule.definition.should == ['  Bar:']
      rules[0].conditions[0].child_rule.definition[0].line_number.should == 2
    end

    it 'associates code segments with rules' do
      rules = parse(:program, <<-EOS, 4)[:rules]
        Foo:
          Bar:
        < exit(0);

        Baz:
        < printf("hi");
        < exit(1);
      EOS

      rules[0].code_segment.should == "exit(0);"
      rules[0].conditions[0].child_rule.code_segment.should be_nil
      rules[1].code_segment.should == "printf(\"hi\");\nexit(1);"
    end
  end

  describe '#parse_rules' do
    it 'allows variables matched once in code segments' do
      lambda {
        parse :rule, <<-EOS, 5
          Foo: X
          < $X->integer_value++;
        EOS
      }.should_not raise_error
    end

    it 'allows variables matched once and referenced multiple times in code segments' do
      lambda {
        parse :rule, <<-EOS, 5
          Foo: X
          +Bar: X
          +Baz: X
          < $X->integer_value++;
        EOS
      }.should_not raise_error
    end

    it 'disallows variables matched multiple times in code segments' do
      lambda {
        parse :program, <<-EOS, 5
          Foo: X
          Bar: X
          < $X->integer_value++;
        EOS
      }.should raise_error(Parser::Error) { |error|
        error.line.line_number.should == 3
        error.line.should == '< $X->integer_value++;'
        error.message.should == 'Multiply-referenced variable in code segment'
      }
    end
  end

  describe '#parse_conditions' do
    it 'includes the top-level conditions' do
      parse(:conditions, <<-EOS, 4).length.should == 2
        Foo:
        Bar:
      EOS
    end

    it 'nests descendant conditions' do
      conditions = parse :conditions, <<-EOS, 4
        Foo:
          Bar:
            Baz:
          Qux:
        FooBar:
      EOS
      conditions.length.should == 2

      foo = conditions[0]
      foo.node_type.should == 'Foo'
      foo.child_rule.conditions.length.should == 2

      bar = foo.child_rule.conditions[0]
      bar.node_type.should == 'Bar'
      bar.child_rule.conditions.length.should == 1

      baz = bar.child_rule.conditions[0]
      baz.node_type.should == 'Baz'
      baz.child_rule.conditions.should be_empty

      qux = foo.child_rule.conditions[1]
      qux.node_type.should == 'Qux'
      qux.child_rule.conditions.should be_empty

      foo_bar = conditions[1]
      foo_bar.node_type.should == 'FooBar'
      foo_bar.child_rule.conditions.should be_empty
    end
  end

  describe '#parse_condition' do
    it 'reads the node type' do
      parse(:condition, 'Foo:').node_type.should == 'Foo'
    end

    it 'considers the node type ^ to mean top level' do
      parse(:condition, '^:').node_type.should == :root
    end

    it 'considers the node type * to mean any node' do
      parse(:condition, '*:').node_type.should == :any
    end

    it 'considers a prepended + to mean creating a node' do
      parse(:condition, 'Foo:').creates_node?.should be_false
      parse(:condition, '+Foo:').creates_node?.should be_true
    end

    it 'considers a prepended - to mean removing a node' do
      parse(:condition, 'Foo:').removes_node?.should be_false
      parse(:condition, '-Foo:').removes_node?.should be_true
    end

    it 'considers a prepended ! to mean preventing a match' do
      parse(:condition, 'Foo:').prevents_match?.should be_false
      parse(:condition, '!Foo:').prevents_match?.should be_true
    end

    it 'only allows one operation' do
      ops = ['+', '-', '!']
      (2..ops.length).each do |num_ops|
        ops.permutation(num_ops).each do |o|
          lambda {
            parse(:condition, "#{o.join}Foo:")
          }.should raise_error(Parser::Error, /only one operation allowed/)
        end
      end
    end

    it 'considers an appended : to mean conditions are ordered' do
      parse(:condition, 'Foo:').child_rule.conditions_are_ordered?.should be_false
      parse(:condition, 'Foo::').child_rule.conditions_are_ordered?.should be_true
    end

    it 'considers an appended = to mean conditions have to match all nodes' do
      parse(:condition, 'Foo:').child_rule.must_match_all_nodes?.should be_false
      parse(:condition, 'Foo:=').child_rule.must_match_all_nodes?.should be_true
    end

    it 'considers an appended * to mean that the condition may match any number of nodes' do
      parse(:condition, 'Foo:').matches_multiple_nodes?.should be_false
      parse(:condition, 'Foo:*').matches_multiple_nodes?.should be_true
    end

    it 'allows ordered, exact, and multiple together' do
      condition = parse :condition, 'Foo::=*'
      condition.child_rule.conditions_are_ordered?.should be_true
      condition.child_rule.must_match_all_nodes?.should be_true
      condition.matches_multiple_nodes?.should be_true
    end
    # TODO: test that the :, =, and * operators must be applied in a specific order

    describe 'values' do
      it 'does not assign a value without one' do
        parse(:condition, 'Foo:').value.should be_nil
      end

      it 'reads the integer value' do
        parse(:condition, 'Foo: 17').value.should == 17
        parse(:condition, 'Foo: 17').value.should be_an(Integer)
      end

      it 'reads the decimal value' do
        parse(:condition, 'Foo: 17.34').value.should == 17.34
      end

      it 'reads negative values' do
        parse(:condition, 'Foo: -17').value.should == -17
        parse(:condition, 'Foo: -17').value.should be_an(Integer)
        parse(:condition, 'Foo: -17.34').value.should == -17.34
      end
    end

    describe 'variables' do
      it 'does not assign a variable without one' do
        parse(:condition, 'Foo:').variable.should be_nil
      end

      it 'assigns the specified variable' do
        parse(:condition, 'Foo: X').variable.should == 'X'
        parse(:condition, 'Foo: blah').variable.should == 'blah'
      end
    end
  end
end
