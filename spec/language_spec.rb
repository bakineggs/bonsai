shared_examples_for 'an okk implementation' do
  def parse_state definition
    nodes = definition.split "\n"
    state = []

    return state if nodes.empty?
    depth = nodes.first.match(/^ */)[0].length

    parent = nodes.shift
    children = []
    nodes.each do |node|
      if node.match /^ {#{depth}}[^ ]/
        state += [{:label => parent.gsub(' ', ''), :children => parse_state(children.join "\n")}]
        parent = node
        children = []
      else
        children += [node]
      end
    end
    state + [{:label => parent.gsub(' ', ''), :children => parse_state(children.join "\n")}]
  end

  it 'errors out when no rules match' do
    result = run_program :rules => "Foo:", :start_state => "Bar:"
    result[:exit_status].should == 1
    result[:stdout].should == ""
    result[:stderr].should == "No rules to apply!\nBar:"
    result[:end_state].should == parse_state(<<-EOS)
      Bar:
    EOS
  end

  it 'errors out when no rules make a change' do
    result = run_program :rules => "Foo:", :start_state => "Foo:"
    result[:exit_status].should == 1
    result[:stdout].should == ""
    result[:stderr].should == "No rules to apply!\nFoo:"
    result[:end_state].should == parse_state(<<-EOS)
      Foo:
    EOS
  end

  it 'executes code of a matched rule' do
    result = run_program :rules => "Foo: < exit(0);", :start_state => "Foo:"
    result[:exit_status].should == 0
    result[:stdout].should == ""
    result[:stderr].should == ""
    result[:end_state].should == parse_state("")
  end

  describe 'root label' do
    it 'applies the rule when conditions match at the root level' do
      rules = <<-EOS
        ^:
          Foo: < exit(0);
      EOS
      start_state = <<-EOS
        Bar:
        Foo:
        Baz:
      EOS
      result = run_program :rules => rules, :start_state => start_state
      result[:exit_status].should == 0
      result[:end_state].should == parse_state("")
    end

    it 'does not apply the rule when conditions match below the root level' do
      rules = <<-EOS
        ^:
          Foo: < exit(0);
      EOS
      start_state = <<-EOS
        Bar:
          Foo:
        Baz:
      EOS
      result = run_program :rules => rules, :start_state => start_state
      result[:exit_status].should == 1
      result[:end_state].should == parse_state(start_state)
    end
  end

  describe 'creating nodes' do
    # TODO
  end

  describe 'removing nodes' do
    # TODO
  end

  describe 'preventing a match' do
    it 'applies the rule if a match-preventing condition does not match' do
      rules = <<-EOS
        !Foo:
        -Bar:
      EOS
      start_state = <<-EOS
        Bar:
        Baz:
      EOS
      result = run_program :rules => rules, :start_state => start_state
      result[:end_state].should == parse_state("Baz:")
    end

    it 'does not apply the rule if a match-preventing condition matches' do
      rules = <<-EOS
        !Foo:
        -Bar:
      EOS
      start_state = <<-EOS
        Bar:
        Foo:
      EOS
      result = run_program :rules => rules, :start_state => start_state
      result[:end_state].should == parse_state(start_state)
    end
  end

  describe 'unordered children' do
    # TODO
  end

  describe 'ordered children' do
    # TODO
  end

  describe 'matching multiple nodes' do
    # TODO
  end

  describe 'node values' do
    # TODO
  end

  describe 'conditions at the top level of a rule' do
    it 'matches them in unordered contexts' do
      rules = <<-EOS
        -Foo:
        -Bar:
      EOS
      start_state = <<-EOS
        Baz:
          Bar:
          Foo:
          Qux:
      EOS
      end_state = <<-EOS
        Baz:
          Qux:
      EOS
      result = run_program :rules => rules, :start_state => start_state
      result[:end_state].should == parse_state(end_state)
    end

    it 'matches them in ordered contexts' do
      rules = <<-EOS
        -Foo:
        -Bar:
      EOS
      start_state = <<-EOS
        Baz::
          Qux:
          Foo:
          Bar:
          FooQux:
      EOS
      end_state = <<-EOS
        Baz:
          Qux:
          FooQux:
      EOS
      result = run_program :rules => rules, :start_state => start_state
      result[:end_state].should == parse_state(end_state)
    end

    it 'does not match them out of order in ordered contexts' do
      rules = <<-EOS
        -Foo:
        -Bar:
      EOS
      start_state = <<-EOS
        Baz::
          Qux:
          Bar:
          Foo:
          FooQux:
      EOS
      result = run_program :rules => rules, :start_state => start_state
      result[:end_state].should == parse_state(start_state)
    end
  end
end
