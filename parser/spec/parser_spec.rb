require 'rspec'
require_relative '../parser'

RSpec.describe Parser do
  def self._it description, program, &block
    program = program.gsub /^#{program.match(/^ */)[0]}/, ''
    it description do
      rules = Parser.new.parse program
      instance_exec rules, &block
    end
  end

  def self._err description, program, line_number, message, unindent = true
    program = program.gsub /^#{program.match(/^ */)[0]}/, '' if unindent
    it description do
      expect { Parser.new.parse program }.to raise_error(Parser::Error) { |error|
        expect(error.message).to eq message.strip
        expect(error.line.line_number).to eq line_number
        expect(error.line).to eq program.split("\n")[line_number - 1]
      }
    end
  end

  describe 'syntax errors' do
    _err 'includes the line of any syntax error', <<-EOS, 3, <<-EOM
      Foo:
        Bar:
          :Baz
        Qux:
    EOS
      Condition could not be parsed
    EOM

    _err 'requires the first condition to be on the top level', <<-EOS, 1, <<-EOM, false
      Foo:
    EOS
      The first condition of a rule must be at the top level
    EOM

    _err 'rejects conditions in between levels', <<-EOS, 2, <<-EOM
      Foo:
       Bar:
    EOS
      Conditions can not be in between levels
    EOM

    _err 'rejects conditions more than one level below their parents', <<-EOS, 2, <<-EOM
      Foo:
          Bar:
    EOS
      Conditions must be at most 1 level below their parents
    EOM

    _err 'does not allow nodes with values to have children', <<-EOS, 1, <<-EOM
      Foo: 16
        Bar:
    EOS
      A condition can not have both a value and a child rule
    EOM

    [2, 3].each do |num_ops|
      ['+', '-', '!'].permutation(num_ops).each do |ops|
        _err 'only allows one operation', <<-EOS, 1, <<-EOM
          #{ops.join}Foo:
        EOS
          Condition could not be parsed
        EOM
      end
    end
  end

  _it 'returns an empty list of rules with an empty program', <<-EOS do |rules|
  EOS
    expect(rules).to be_empty
  end

  _it 'ignores empty lines', <<-EOS do |rules|
    
  EOS
    expect(rules).to be_empty
  end

  _it 'ignores empty lines between rules', <<-EOS do |rules|
    
    Foo:
    
    
    Bar:
    
  EOS
    expect(rules.length).to eq 2
  end

  _it 'ignores comments', <<-EOS do |rules|
    Foo: # comment

    # another comment

    # yet another comment
    Bar:
  EOS
    expect(rules.length).to eq 2
  end

  _it 'does not treat a whole-line comment as a rule separator', <<-EOS do |rules|
    Foo:
    # comment
    Bar:
  EOS
    expect(rules.length).to eq 1
  end

  ['Foo:', 'Foo::'].each do |rules|
    _it 'considers a top level rule to have unordered conditions', rules do |rules|
      expect(rules.first.conditions_are_ordered?).to eq false
    end
  end

  ['Foo:', 'Foo:='].each do |rules|
    _it 'considers a top level rule to not require all nodes to be matched', rules do |rules|
      expect(rules.first.must_match_all_nodes?).to eq false
    end
  end

  _it 'includes the conditions of a rule', <<-EOS do |rules|
    Foo:
    Bar:

    Baz:
  EOS
    expect(rules[0].conditions.map &:label).to eq ['Foo', 'Bar']
    expect(rules[1].conditions.map &:label).to eq ['Baz']
  end

  _it 'nests descendant conditions', <<-EOS do |rules|
    Foo:
      Bar:
        Baz:
      Qux:
    FooBar:
  EOS
    expect(rules.length).to eq 1
    expect(rules[0].conditions.length).to eq 2

    foo = rules[0].conditions[0]
    expect(foo.label).to eq 'Foo'
    expect(foo.child_rule.conditions.length).to eq 2

    bar = foo.child_rule.conditions[0]
    expect(bar.label).to eq 'Bar'
    expect(bar.child_rule.conditions.length).to eq 1

    baz = bar.child_rule.conditions[0]
    expect(baz.label).to eq 'Baz'
    expect(baz.child_rule.conditions).to be_empty

    qux = foo.child_rule.conditions[1]
    expect(qux.label).to eq 'Qux'
    expect(qux.child_rule.conditions).to be_empty

    foobar = rules[0].conditions[1]
    expect(foobar.label).to eq 'FooBar'
    expect(foobar.child_rule.conditions).to be_empty
  end

  _it 'includes the definitions of the rules', <<-EOS do |rules|
    Foo:
      Bar:

    Baz:
  EOS
    expect(rules[0].definition).to eq ['Foo:', '  Bar:']
    expect(rules[0].definition[0].line_number).to eq 1
    expect(rules[0].definition[1].line_number).to eq 2

    expect(rules[1].definition).to eq ['Baz:']
    expect(rules[1].definition[0].line_number).to eq 4

    expect(rules[0].conditions[0].child_rule.definition).to eq ['  Bar:']
    expect(rules[0].conditions[0].child_rule.definition[0].line_number).to eq 2
  end

  ['Foo', '^', '*'].each do |label|
    _it 'reads the node label for a condition', <<-EOS do |rules|
      #{label}:
    EOS
      expect(rules.first.conditions.first.label).to eq label
    end
  end

  _it 'considers conditions with a + to create a node', <<-EOS do |rules|
    Foo:
    +Bar:
  EOS
    expect(rules.first.conditions.first.creates_node?).to eq false
    expect(rules.first.conditions.last.creates_node?).to eq true
  end

  _it 'considers conditions with a - to remove a node', <<-EOS do |rules|
    Foo:
    -Bar:
  EOS
    expect(rules.first.conditions.first.removes_node?).to eq false
    expect(rules.first.conditions.last.removes_node?).to eq true
  end

  _it 'considers conditions with a ! to prevent a match', <<-EOS do |rules|
    Foo:
    !Bar:
  EOS
    expect(rules.first.conditions.first.prevents_match?).to eq false
    expect(rules.first.conditions.last.prevents_match?).to eq true
  end

  _it 'considers conditions with a prepended ... to match descendant conditions', <<-EOS do |rules|
    Foo:
    ...Bar:
  EOS
    expect(rules.first.conditions.first.matches_descendants?).to eq false
    expect(rules.first.conditions.last.matches_descendants?).to eq true
  end

  _it 'considers conditions with an appended : to have a child rule with ordered conditions', <<-EOS do |rules|
    Foo:
    Bar::
  EOS
    expect(rules.first.conditions.first.child_rule.conditions_are_ordered?).to eq false
    expect(rules.first.conditions.last.child_rule.conditions_are_ordered?).to eq true
  end

  _it 'considers conditions with an appended = to have a child rule that must match all nodes', <<-EOS do |rules|
    Foo:
    Bar:=
  EOS
    expect(rules.first.conditions.first.child_rule.must_match_all_nodes?).to eq false
    expect(rules.first.conditions.last.child_rule.must_match_all_nodes?).to eq true
  end

  _it 'considers conditions with an appended * to match multiple nodes', <<-EOS do |rules|
    Foo:
    Bar:*
  EOS
    expect(rules.first.conditions.first.matches_multiple_nodes?).to eq false
    expect(rules.first.conditions.last.matches_multiple_nodes?).to eq true
  end

  [':=', ':*', '=*', ':=*'].each do |appendage|
    _it 'allows the :, =, and * operators to be used together in order', <<-EOS do |rules|
      Foo:#{appendage}
    EOS
      expect(rules.first.conditions.first.child_rule.conditions_are_ordered?).to eq appendage.include? ':'
      expect(rules.first.conditions.first.child_rule.must_match_all_nodes?).to eq appendage.include? '='
      expect(rules.first.conditions.first.matches_multiple_nodes?).to eq appendage.include? '*'
    end
  end

  ['*=', '*:', '=:', '*=:', '*:=', '=*:', '=:*', ':*='].each do |appendage|
    _err 'requires the :, =, and * operators to be used in that order', <<-EOS, 1, <<-EOM
      Foo:#{appendage}
    EOS
      Condition could not be parsed
    EOM
  end

  _it 'allows integer, decimal, or string values', <<-EOS do |rules|
    Foo:
    Foo: 17
    Foo: -17
    Foo: 17.34
    Foo: -17.34
    Foo: "bar"
  EOS
    expect(rules.first.conditions[0].value).to eq nil
    expect(rules.first.conditions[1].value).to eq 17
    expect(rules.first.conditions[1].value.is_a? Fixnum).to eq true
    expect(rules.first.conditions[2].value).to eq -17
    expect(rules.first.conditions[2].value.is_a? Fixnum).to eq true
    expect(rules.first.conditions[3].value).to eq 17.34
    expect(rules.first.conditions[4].value).to eq -17.34
    expect(rules.first.conditions[5].value).to eq "bar"
  end

  _it 'allows variables assigned to conditions', <<-EOS do |rules|
    Foo:
    Foo: X
    Foo: blah2you
  EOS
    expect(rules.first.conditions[0].variable).to eq nil
    expect(rules.first.conditions[1].variable).to eq "X"
    expect(rules.first.conditions[2].variable).to eq "blah2you"
  end

  _err 'does not allow variable names to start with a number', <<-EOS, 1, <<-EOM
    Foo: 2you
  EOS
    Condition could not be parsed
  EOM

  _it 'allows variables that match multiple nodes', <<-EOS do |rules|
    Foo:* X
    Foo:* [Y]
  EOS
    expect(rules.first.conditions[0].variable).to eq 'X'
    expect(rules.first.conditions[0].variable_matches_multiple_nodes?).to eq false
    expect(rules.first.conditions[1].variable).to eq 'Y'
    expect(rules.first.conditions[1].variable_matches_multiple_nodes?).to eq true
  end

  _err 'does not allow variables that match multiple nodes assigned to conditions that do not match multiple nodes', <<-EOS, 1, <<-EOM
    Foo: [X]
  EOS
    A condition can not have a variable that matches multiple nodes without matching multiple nodes
  EOM

  _it 'allows variables assigned to a wildcard label to require matching labels', <<-EOS do |rules|
    *: A
    *: =B
    *:* [C]
    *:* =[D]
  EOS
    expect(rules.first.conditions[0].variable).to eq 'A'
    expect(rules.first.conditions[0].variable_matches_labels?).to eq false
    expect(rules.first.conditions[1].variable).to eq 'B'
    expect(rules.first.conditions[1].variable_matches_labels?).to eq true
    expect(rules.first.conditions[2].variable).to eq 'C'
    expect(rules.first.conditions[2].variable_matches_labels?).to eq false
    expect(rules.first.conditions[3].variable).to eq 'D'
    expect(rules.first.conditions[3].variable_matches_labels?).to eq true
  end

  _err 'does not allow variables that require matching labels assigned to conditions that do not use a wildcard label', <<-EOS, 1, <<-EOM
    Foo: =X
  EOS
    A condition can not have a variable that matches labels without a wildcard label
  EOM

  _err 'does not allow variables that require matching labels assigned to conditions matching multiple nodes that do not use a wildcard label', <<-EOS, 1, <<-EOM
    Foo:* =[X]
  EOS
    A condition can not have a variable that matches labels without a wildcard label
  EOM
end
