require 'spec'
require File.dirname(__FILE__) + '/../../compiler/parser'

describe Parser do
  def parse type, body, depth = 0
    Parser.new.send :"parse_#{type}", body.gsub(/^ {#{depth * 2}}/, '')
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

      rule = parser.parse_rule(<<-EOS.gsub /^ {8}/, '')
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

      rule = parser.parse_rule(<<-EOS.gsub /^ {8}/, '')
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
  end
end
