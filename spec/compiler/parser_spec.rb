require 'spec'
require File.dirname(__FILE__) + '/../../compiler/parser'

describe Parser do
  def parse type, body, depth = 0
    body.gsub! /^ {#{depth * 2}}/, ''
    body = body.split "\n" if type == :rule
    Parser.new.send :"parse_#{type}", body
  end

  describe '#parse_rules' do
    it 'returns an empty list of rules with an empty program' do
      parse(:rules, "").should be_empty
    end

    it 'ignores empty lines' do
      parse(:rules, <<-EOS, 4).should be_empty

      EOS
    end

    it 'ignores empty lines between rules' do
      parse(:rules, <<-EOS, 4).length.should == 2

        Foo:


        Bar:

      EOS
    end

    it 'ignores comments' do
      parse(:rules, <<-EOS, 4).length.should == 2
        Foo: # comment

        # another comment

        # yet another comment
        Bar:
      EOS
    end

    it 'treats a whole-line comment as a rule separator' do
      parse(:rules, <<-EOS, 4).length.should == 2
        Foo:
        # comment
        Bar:
      EOS
    end

    it 'includes the line of any syntax error' do
      lambda {
        parse :rules, <<-EOS, 5
          Foo:
            Bar:
              :Baz
            Qux:
        EOS
      }.should raise_error(Parser::Error) do |error|
        error.line.line_number.should == 3
        error.line.should == "    :Baz"
      end
    end

    it 'requires the first condition to be on the top level' do
      lambda {
        rule = parse :rule, <<-EOS, 5
            Foo:
        EOS
      }.should raise_error(Parser::Error) do |error|
        error.line.line_number.should == 1
        error.line.should == "  Foo:"
        error.message.should == "The first condition of a rule must be at the top level"
      end
    end

    it 'rejects conditions in between levels' do
      lambda {
        rule = parse :rule, <<-EOS, 5
          Foo:
           Bar:
        EOS
      }.should raise_error(Parser::Error) do |error|
        error.line.line_number.should == 2
        error.line.should == " Bar:"
        error.message.should == "Conditions can not be in between levels"
      end
    end

    it 'rejects conditions more than one level below their parents' do
      lambda {
        rule = parse :rule, <<-EOS, 5
          Foo:
              Bar:
        EOS
      }.should raise_error(Parser::Error) do |error|
        error.line.line_number.should == 2
        error.line.should == "    Bar:"
        error.message.should == "Conditions must be at most 1 level below their parents"
      end
    end
  end

  describe '#parse_rule' do
    it 'includes the top-level conditions' do
      rule = parse :rule, <<-EOS, 4
        Foo:
        Bar:
      EOS
      rule.conditions.length.should == 2
    end

    it 'nests descendant conditions' do
      rule = parse :rule, <<-EOS, 4
        Foo:
          Bar:
            Baz:
          Qux:
        FooBar:
      EOS
      rule.conditions.length.should == 2

      foo = rule.conditions[0].child
      foo.node_type.should == 'Foo'
      foo.conditions.length.should == 2

      bar = foo.conditions[0].child
      bar.node_type.should == 'Bar'
      bar.conditions.length.should == 1

      baz = bar.conditions[0].child
      baz.node_type.should == 'Baz'
      baz.conditions.should be_empty

      qux = foo.conditions[1].child
      qux.node_type.should == 'Qux'
      qux.conditions.should be_empty

      foo_bar = rule.conditions[1]
      foo_bar.node_type.should == 'FooBar'
      foo_bar.conditions.should be_empty
    end

    it 'considers the top level rule to have unordered conditions' do
      rule = parse :rule, <<-EOS, 4
        Foo:
      EOS
      rule.conditions_are_ordered?.should be_false

      rule = parser.parse :rule, <<-EOS, 4
        Foo::
      EOS
      rule.conditions_are_ordered?.should be_false
    end

    it 'considers one colon to mean conditions are unordered' do
      rule = parse :rule, <<-EOS, 4
        Foo:
      EOS
      rule.conditions[0].child.conditions_are_ordered?.should be_false
    end

    it 'considers two colons to mean conditions are ordered' do
      rule = parse :rule, <<-EOS, 4
        Foo::
      EOS
      rule.conditions[0].child.conditions_are_ordered?.should be_true
    end

    it 'considers the top rule to not require conditions to match all nodes' do
      rule = parse :rule, <<-EOS, 4
        Foo:
      EOS
      rule.requires_exact_match?.should be_false

      rule = parser.parse :rule, <<-EOS, 4
        Foo:=
      EOS
      rule.requires_exact_match?.should be_false
    end

    it 'considers lack of an equals sign to mean conditions do not have to match all nodes' do
      rule = parse :rule, <<-EOS, 4
        Foo:
      EOS
      rule.conditions[0].child.requires_exact_match?.should be_false
    end

    it 'considers an equals sign to mean conditions have to match all nodes' do
      rule = parse :rule, <<-EOS, 4
        Foo:=
      EOS
      rule.conditions[0].child.requires_exact_match?.should be_true
    end

    it 'allows ordered and exact together' do
      rule = parse :rule, <<-EOS, 4
        Foo::=
      EOS
      rule.conditions[0].child.conditions_are_ordered?.should be_true
      rule.conditions[0].child.requires_exact_match?.should be_true
    end
  end

  describe '#parse_condition' do
    it 'reads the node type' do
      parse(:condition, 'Foo:').node_type.should == 'Foo'
    end

    it 'considers the node type ^ to mean top level' do
      parse(:condition, '^:').node_type.should == :top
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

    it 'considers an appended * to mean that the condition may match any number of nodes' do
      parse(:condition, 'Foo:').matches_many_nodes?.should be_false
      parse(:condition, 'Foo:*').matches_many_nodes?.should be_true
    end

    it 'does not assign a value without one' do
      parse(:condition, 'Foo:').value.should be_nil
    end

    it 'reads the integer value' do
      parse(:condition, 'Foo: 17').value.should == 17
      parse(:condition, 'Foo: 17').value.should be_an(Integer)
    end

    it 'reads the real value' do
      parse(:condition, 'Foo: 17.34').value.should == 17.34
    end
  end
end