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
    describe 'at the root level' do
      it 'creates the node' do
        rules = <<-EOS
          Foo: < exit(0);

          +Foo:
        EOS
        result = run_program :rules => rules, :start_state => ''
        result[:exit_status].should == 0
      end
    end

    describe 'in a child condition' do
      describe 'with a matching parent' do
        it 'creates the node' do
          rules = <<-EOS
            Foo: < exit(0);

            Bar:
              +Foo:
          EOS
          result = run_program :rules => rules, :start_state => 'Bar:'
          result[:exit_status].should == 0
        end
      end

      describe 'without a matching parent' do
        it 'does not create the node' do
          rules = <<-EOS
            Foo: < exit(0);

            Bar:
              +Foo:
          EOS
          result = run_program :rules => rules, :start_state => 'Baz:'
          result[:exit_status].should == 1
          result[:end_state].should == parse_state('Baz:')
        end
      end
    end

    describe 'with children' do
      it 'creates the children' do
        rules = <<-EOS
          Foo: < exit(0);

          +Bar:
            Foo:
        EOS
        result = run_program :rules => rules, :start_state => ''
        result[:exit_status].should == 0
      end
    end
  end

  describe 'removing nodes' do
    describe 'at the root level' do
      it 'removes the node' do
        result = run_program :rules => '-Foo:', :start_state => 'Foo:'
        result[:exit_status].should == 1
        result[:end_state].should == parse_state('')
      end
    end

    describe 'in a child condition' do
      it 'removes the node' do
        rules = <<-EOS
          Foo:
            -Bar:
        EOS
        start_state = <<-EOS
          Foo:
            Bar:
        EOS
        result = run_program :rules => rules, :start_state => start_state
        result[:exit_status].should == 1
        result[:end_state].should == parse_state('Foo:')
      end
    end

    describe 'with children' do
      describe 'that match' do
        it 'removes the node' do
          rules = <<-EOS
            -Foo:
              Bar:
          EOS
          start_state = <<-EOS
            Foo:
              Bar:
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:exit_status].should == 1
          result[:end_state].should == parse_state('')
        end
      end

      describe 'that do not match' do
        it 'does not remove the node' do
          rules = <<-EOS
            -Foo:
              Bar:
          EOS
          start_state = <<-EOS
            Foo:
              Baz:
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:exit_status].should == 1
          result[:end_state].should == parse_state(start_state)
        end
      end
    end
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

  describe 'unordered child conditions' do
    let(:rules) do
      <<-EOS
        Foo:
          Bar:
          Baz: < exit(0);
      EOS
    end

    describe 'matching unordered child nodes' do
      describe 'that match in order' do
        it 'applies the rule' do
          start_state = <<-EOS
            Foo:
              Bar:
              Baz:
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:exit_status].should == 0
        end
      end

      describe 'that match out of order' do
        it 'applies the rule' do
          start_state = <<-EOS
            Foo:
              Baz:
              Bar:
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:exit_status].should == 0
        end
      end
    end

    describe 'matching ordered child nodes' do
      describe 'that match in order' do
        it 'applies the rule' do
          start_state = <<-EOS
            Foo::
              Bar:
              Baz:
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:exit_status].should == 0
        end
      end

      describe 'that match out of order' do
        it 'applies the rule' do
          start_state = <<-EOS
            Foo::
              Baz:
              Bar:
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:exit_status].should == 0
        end
      end
    end
  end

  describe 'ordered child conditions' do
    let(:rules) do
      <<-EOS
        Foo::
          Bar:
          Baz: < exit(0);
      EOS
    end

    describe 'matching unordered child nodes' do
      describe 'that match in order' do
        it 'does not apply the rule' do
          start_state = <<-EOS
            Foo:
              Bar:
              Baz:
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:exit_status].should == 1
          result[:end_state].should == parse_state(start_state)
        end
      end

      describe 'that match out of order' do
        it 'does not apply the rule' do
          start_state = <<-EOS
            Foo:
              Baz:
              Bar:
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:exit_status].should == 1
          result[:end_state].should == parse_state(start_state)
        end
      end
    end

    describe 'matching ordered child nodes' do
      describe 'that match in order' do
        it 'applies the rule' do
          start_state = <<-EOS
            Foo::
              Bar:
              Baz:
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:exit_status].should == 0
        end
      end

      describe 'that match out of order' do
        it 'does not apply the rule' do
          start_state = <<-EOS
            Foo::
              Baz:
              Bar:
          EOS
          result = run_program :rules => rules, :start_state => start_state
          result[:exit_status].should == 1
          result[:end_state].should == parse_state(start_state)
        end
      end
    end
  end

  describe 'matching multiple nodes' do
    let(:rules) do
      <<-EOS
        -Foo:
        -Bar:*
      EOS
    end

    describe 'with no nodes that match' do
      it 'applies the rule' do
        start_state = <<-EOS
          Foo:
        EOS
        result = run_program :rules => rules, :start_state => start_state
        result[:exit_status].should == 1
        result[:end_state].should == parse_state('')
      end
    end

    describe 'with one node that matches' do
      it 'applies the rule' do
        start_state = <<-EOS
          Foo:
          Bar:
        EOS
        result = run_program :rules => rules, :start_state => start_state
        result[:exit_status].should == 1
        result[:end_state].should == parse_state('')
      end
    end

    describe 'with multiple nodes that match' do
      it 'applies the rule' do
        start_state = <<-EOS
          Foo:
          Bar:
          Bar:
        EOS
        result = run_program :rules => rules, :start_state => start_state
        result[:exit_status].should == 1
        result[:end_state].should == parse_state('')
      end
    end
  end

  describe 'not matching all nodes with a condition' do
    let(:rules) do
      <<-EOS
        Foo:
          Bar:
          Baz: < exit(0);
      EOS
    end

    describe 'with all child nodes matching' do
      it 'applies the rule' do
        start_state = <<-EOS
          Foo:
            Bar:
            Baz:
        EOS
        result = run_program :rules => rules, :start_state => start_state
        result[:exit_status].should == 0
      end
    end

    describe 'with some child nodes not matching' do
      it 'applies the rule' do
        start_state = <<-EOS
          Foo:
            Bar:
            Baz:
            Qux:
        EOS
        result = run_program :rules => rules, :start_state => start_state
        result[:exit_status].should == 0
      end
    end
  end

  describe 'matching all nodes with a condition' do
    let(:rules) do
      <<-EOS
        Foo:=
          Bar:
          Baz: < exit(0);
      EOS
    end

    describe 'with all child nodes matching' do
      it 'applies the rule' do
        start_state = <<-EOS
          Foo:
            Bar:
            Baz:
        EOS
        result = run_program :rules => rules, :start_state => start_state
        result[:exit_status].should == 0
      end
    end

    describe 'with some child nodes not matching' do
      it 'does not apply the rule' do
        start_state = <<-EOS
          Foo:
            Bar:
            Baz:
            Qux:
        EOS
        result = run_program :rules => rules, :start_state => start_state
        result[:exit_status].should == 1
        result[:end_state].should == parse_state(start_state)
      end
    end
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
      EOS
      result = run_program :rules => rules, :start_state => start_state
      result[:end_state].should == parse_state('Baz:')
    end

    it 'matches them in ordered contexts' do
      rules = <<-EOS
        -Foo:
        -Bar:
      EOS
      start_state = <<-EOS
        Baz::
          Foo:
          Bar:
      EOS
      result = run_program :rules => rules, :start_state => start_state
      result[:end_state].should == parse_state('Baz:')
    end

    it 'does not match them out of order in ordered contexts' do
      rules = <<-EOS
        -Foo:
        -Bar:
      EOS
      start_state = <<-EOS
        Baz::
          Bar:
          Foo:
      EOS
      result = run_program :rules => rules, :start_state => start_state
      result[:end_state].should == parse_state(start_state)
    end
  end
end
